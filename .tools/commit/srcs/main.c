#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "auto_commit.h"
#include "git_utils.h"
#include "commit_builder.h"
#include "commit_rules.h"
#include "utf8.h"
#include "version.h"

static t_commit_type eGitCharToType(char c)
{
	switch (c)
	{
		case 'A': return COMMIT_ADD;
		case '?': return COMMIT_ADD;
		case 'M': return COMMIT_MODIFY;
		case 'D': return COMMIT_DELETE;
		case 'R': return COMMIT_RENAME;
		default:  return COMMIT_UNKNOWN;
	}
}

static void vParseArgs(int argc, char **argv, int *bSafeMode, int *bNoVersion)
{
	for (int i = 1; i < argc; i++)
	{
		if (strcmp(argv[i], "--safe") == 0)
			*bSafeMode = 1;
		else if (strcmp(argv[i], "--no-version") == 0)
			*bNoVersion = 1;
	}
}

static int bInitEnvironment(t_version *ver, int bNoVersion)
{
	vInitUtf8();

	if (!bLoadCommitRules("commit_config.json"))
	{
		printf("[ERREUR] Impossible de charger commit_config.json\n");
		return 0;
	}

	if (!bNoVersion)
		bLoadVersion(ver);

	return 1;
}

static char *sCreateTempFile(size_t index)
{
	char name[256];
	snprintf(name, sizeof(name), ".commitmsg_%lu_%zu.tmp",
		(unsigned long)time(NULL), index);

	FILE *fp = fopen(name, "wb");
	if (!fp)
		return NULL;
	fclose(fp);

	return strdup(name);
}

static void vBuildGitCmd(
	char *dst,
	size_t dstSize,
	const t_git_file *pFile,
	const char *tmpFile,
	t_commit_type eType,
	int bNoVersion
) {
	if (bNoVersion)
	{
		switch (eType)
		{
			case COMMIT_ADD:
			case COMMIT_MODIFY:
			case COMMIT_RENAME:
				snprintf(dst, dstSize,
					"git add \"%s\" && git commit -F \"%s\" -- \"%s\"",
					pFile->sPath, tmpFile, pFile->sPath);
				break;

			case COMMIT_DELETE:
				snprintf(dst, dstSize,
					"git rm \"%s\" && git commit -F \"%s\" -- \"%s\"",
					pFile->sPath, tmpFile, pFile->sPath);
				break;

			default:
				snprintf(dst, dstSize, "echo \"[UNKNOWN]\"");
				break;
		}
	}
	else
	{
		switch (eType)
		{
			case COMMIT_ADD:
			case COMMIT_MODIFY:
			case COMMIT_RENAME:
				snprintf(dst, dstSize,
					"git add \"%s\" VERSION && git commit -F \"%s\" -- \"%s\" VERSION",
					pFile->sPath, tmpFile, pFile->sPath);
				break;

			case COMMIT_DELETE:
				snprintf(dst, dstSize,
					"git rm \"%s\" && git add VERSION && git commit -F \"%s\" -- \"%s\" VERSION",
					pFile->sPath, tmpFile, pFile->sPath);
				break;

			default:
				snprintf(dst, dstSize, "echo \"[UNKNOWN]\"");
				break;
		}
	}
}

static int bProcessFile(
	const t_git_file *pFile,
	size_t iIndex,
	t_version *ver,
	int bSafeMode,
	int bNoVersion
) {
	t_commit_type eType = eGitCharToType(pFile->cStatus);
	int exists = (access(pFile->sPath, F_OK) == 0);

	char *msg = strBuildCommitMessage(pFile->sPath, eType);
	if (!msg)
		return 1;

	char verStr[32] = {0};

	if (!bNoVersion)
	{
		vIncrementVersion(ver, 1);
		bSaveVersion(ver);
		snprintf(verStr, sizeof(verStr), "%d.%d.%d", ver->major, ver->minor, ver->patch);
	}

	if (bSafeMode)
	{
		printf("[SAFE] %zu | status='%c' | exists=%d | path='%s'\n",
			iIndex, pFile->cStatus, exists, pFile->sPath);
		printf("[SAFE] msg: %s\n", msg);
		if (!bNoVersion)
			printf("[SAFE] new version: %s\n", verStr);
		else
			printf("[SAFE] version disabled\n");

		free(msg);
		return 1;
	}

	if (eType == COMMIT_DELETE && !exists)
	{
		printf("[SKIP] Deleted file not present: %s\n", pFile->sPath);
		free(msg);
		return 1;
	}

	char *tmp = sCreateTempFile(iIndex);
	if (!tmp)
	{
		free(msg);
		return 1;
	}

	FILE *fp = fopen(tmp, "wb");
	if (!fp)
	{
		free(tmp);
		free(msg);
		return 1;
	}
	fwrite(msg, 1, strlen(msg), fp);
	fclose(fp);

	char cmd[2048];
	vBuildGitCmd(cmd, sizeof(cmd), pFile, tmp, eType, bNoVersion);

	iRunGitCommand(cmd);

	remove(tmp);
	free(tmp);
	free(msg);
	return 1;
}

int main(int argc, char **argv)
{
	int bSafe = 0;
	int bNoVersion = 0;
	t_version ver;

	vParseArgs(argc, argv, &bSafe, &bNoVersion);

	if (!bInitEnvironment(&ver, bNoVersion))
		return 1;

	size_t count;
	t_git_file *files = arrGetGitFiles(&count);
	if (!files || count == 0)
	{
		printf("[INFO] Aucun fichier modifié.\n");
		return 0;
	}

	for (size_t i = 0; i < count; i++)
		bProcessFile(&files[i], i, &ver, bSafe, bNoVersion);

	vcFreeGitFiles(files, count);
	vFreeCommitRules();
	return 0;
}
