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

int main(int argc, char **argv)
{
	t_git_file *arrFiles;
	size_t iFileCount;
	int bSafeMode = 0;
	t_version ver;

	if (argc > 1 && strcmp(argv[1], "--safe") == 0)
		bSafeMode = 1;

	vInitUtf8();
	bLoadVersion(&ver);

	if (!bLoadCommitRules("commit_config.json")) {
		printf("[ERREUR] Impossible de charger commit_config.json\n");
		return 1;
	}

	arrFiles = arrGetGitFiles(&iFileCount);
	if (!arrFiles || iFileCount == 0)
	{
		printf("[INFO] Aucun fichier modifié détecté.\n");
		return 0;
	}

	for (size_t i = 0; i < iFileCount; i++)
	{
		t_commit_type eType = eGitCharToType(arrFiles[i].cStatus);
		int exists = (access(arrFiles[i].sPath, F_OK) == 0);

		char *sMsg = strBuildCommitMessage(arrFiles[i].sPath, eType);
		if (!sMsg) continue;

		vIncrementVersion(&ver, 1);
		bSaveVersion(&ver);

		char sVersionStr[32];
		snprintf(sVersionStr, sizeof(sVersionStr), "%d.%d.%d", ver.major, ver.minor, ver.patch);

		if (bSafeMode)
		{
			printf("[SAFE DEBUG] %zu | status='%c' | exists=%d | path='%s'\n",
				i, arrFiles[i].cStatus, exists, arrFiles[i].sPath);
			printf("[SAFE DEBUG] commit message: %s\n", sMsg);
			printf("[SAFE DEBUG] new version: %s\n", sVersionStr);
			free(sMsg);
			continue;
		}

		if (eType == COMMIT_DELETE && !exists)
		{
			printf("[SKIP] Deleted file not on disk: %s\n", arrFiles[i].sPath);
			free(sMsg);
			continue;
		}

		char sTmpName[256];
		snprintf(sTmpName, sizeof(sTmpName), ".commitmsg_%lu_%zu.tmp", (unsigned long)time(NULL), i);

		FILE *pTmp = fopen(sTmpName, "wb");
		if (!pTmp)
		{
			free(sMsg);
			continue;
		}
		fwrite(sMsg, 1, strlen(sMsg), pTmp);
		fclose(pTmp);

		char sCmd[2048];
		switch (eType)
		{
			case COMMIT_ADD:
			case COMMIT_MODIFY:
			case COMMIT_RENAME:
				snprintf(sCmd, sizeof(sCmd),
					"git add \"%s\" VERSION && git commit -F \"%s\" -- \"%s\" VERSION",
					arrFiles[i].sPath, sTmpName, arrFiles[i].sPath);
				break;
			case COMMIT_DELETE:
				snprintf(sCmd, sizeof(sCmd),
					"git rm \"%s\" && git add VERSION && git commit -F \"%s\" -- \"%s\" VERSION",
					arrFiles[i].sPath, sTmpName, arrFiles[i].sPath);
				break;
			default:
				snprintf(sCmd, sizeof(sCmd), "echo \"[UNKNOWN] %s\"", sMsg);
				break;
		}

		iRunGitCommand(sCmd);
		remove(sTmpName);
		free(sMsg);
	}

	vcFreeGitFiles(arrFiles, iFileCount);
	vFreeCommitRules();
	return 0;
}
