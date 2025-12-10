#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "git_utils.h"

#ifdef _WIN32
# define POPEN _popen
# define PCLOSE _pclose
#else
# define POPEN popen
# define PCLOSE pclose
#endif

t_git_file *arrGetGitFiles(size_t *piCount)
{
	FILE *p;
	char buf[4096];
	size_t iCap = 16;
	size_t iLen = 0;
	t_git_file *arr;

	*piCount = 0;

	p = POPEN("git diff --name-status HEAD && git ls-files --others --exclude-standard", "r");
	if (!p)
		return NULL;

	arr = malloc(sizeof(t_git_file) * iCap);
	if (!arr)
	{
		PCLOSE(p);
		return NULL;
	}

	while (fgets(buf, sizeof(buf), p))
	{
		size_t len = strlen(buf);
		while (len > 0 && (buf[len-1] == '\n' || buf[len-1] == '\r'))
			buf[--len] = '\0';
		if (len == 0)
			continue;

		char cStatus;
		char *sPath1 = NULL;
		char *sPath2 = NULL;

		if (buf[0] == 'R')
		{
			cStatus = 'R';
			char *tab1 = strchr(buf, '\t');
			if (!tab1) continue;
			*tab1 = 0;
			sPath1 = tab1 + 1;

			char *tab2 = strchr(sPath1, '\t');
			if (!tab2) continue;
			*tab2 = 0;
			sPath2 = tab2 + 1;
		}
		else if (buf[0] == 'A' || buf[0] == 'M' || buf[0] == 'D')
		{
			cStatus = buf[0];
			sPath1 = buf + 1;
			while (*sPath1 == '\t' || *sPath1 == ' ')
				sPath1++;
		}
		else
		{
			cStatus = '?';
			sPath1 = buf;
		}

		if (iLen + (sPath2 ? 2 : 1) >= iCap)
		{
			iCap *= 2;
			t_git_file *tmp = realloc(arr, sizeof(t_git_file) * iCap);
			if (!tmp) break;
			arr = tmp;
		}

		char *dup1 = strdup(sPath1);
		if (!dup1) continue;
		arr[iLen].cStatus = cStatus;
		arr[iLen].sPath = dup1;
		iLen++;

		if (sPath2)
		{
			char *dup2 = strdup(sPath2);
			if (!dup2) continue;
			arr[iLen].cStatus = cStatus;
			arr[iLen].sPath = dup2;
			iLen++;
		}
	}

	PCLOSE(p);

	if (iLen == 0)
	{
		free(arr);
		return NULL;
	}

	*piCount = iLen;
	return arr;
}

int iRunGitCommand(const char *sCmd)
{
	if (!sCmd) return 1;
	return system(sCmd);
}

void vcFreeGitFiles(t_git_file *arr, size_t iCount)
{
	for (size_t i = 0; i < iCount; i++)
		free(arr[i].sPath);
	free(arr);
}
