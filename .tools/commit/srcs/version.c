#include "version.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char *VERSION_FILE = "VERSION";

bool bLoadVersion(t_version *pVer)
{
	FILE *pFile = fopen(VERSION_FILE, "r");
	if (!pFile)
	{
		pVer->major = pVer->minor = pVer->patch = 0;
		pVer->commit[0] = '\0';
		return false;
	}

	char sLine[64];
	if (!fgets(sLine, sizeof(sLine), pFile))
	{
		fclose(pFile);
		return false;
	}
	fclose(pFile);

	char *dot1 = strchr(sLine, '.');
	char *dot2 = dot1 ? strchr(dot1 + 1, '.') : NULL;
	char *space = strchr(sLine, ' ');
	if (dot1 && dot2)
	{
		pVer->major = atoi(sLine);
		pVer->minor = atoi(dot1 + 1);
		pVer->patch = atoi(dot2 + 1);
		if (space)
			strncpy(pVer->commit, space + 1, sizeof(pVer->commit) - 1);
		else
			pVer->commit[0] = '\0';
		pVer->commit[sizeof(pVer->commit) - 1] = '\0';
		return true;
	}
	return false;
}

bool bSaveVersion(const t_version *pVer)
{
	FILE *pFile = fopen(VERSION_FILE, "w");
	if (!pFile)
		return false;
	fprintf(pFile, "%d.%d.%d", pVer->major, pVer->minor, pVer->patch);
	if (pVer->commit[0])
		fprintf(pFile, " %s", pVer->commit);
	fprintf(pFile, "\n");
	fclose(pFile);
	return true;
}

void vIncrementVersion(t_version *pVer, bool bIncrement)
{
	if (!bIncrement)
		return;
	pVer->patch++;
	if (pVer->patch >= 100)
	{
		pVer->patch = 0;
		pVer->minor++;
		if (pVer->minor >= 100)
		{
			pVer->minor = 0;
			pVer->major++;
		}
	}
}

void vUpdateCommitHash(t_version *pVer)
{
	FILE *pPipe = popen("git rev-parse --short HEAD", "r");
	if (!pPipe)
	{
		pVer->commit[0] = '\0';
		return;
	}
	if (!fgets(pVer->commit, sizeof(pVer->commit), pPipe))
		pVer->commit[0] = '\0';
	else
	{
		size_t len = strlen(pVer->commit);
		if (len && (pVer->commit[len - 1] == '\n' || pVer->commit[len - 1] == '\r'))
			pVer->commit[len - 1] = '\0';
	}
	pclose(pPipe);
}

void vGetVersionString(const t_version *pVer, char *sOut, size_t iSize)
{
	if (pVer->commit[0])
		snprintf(sOut, iSize, "%d.%d.%d.%s", pVer->major, pVer->minor, pVer->patch, pVer->commit);
	else
		snprintf(sOut, iSize, "%d.%d.%d", pVer->major, pVer->minor, pVer->patch);
}
