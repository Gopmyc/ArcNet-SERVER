#ifndef GIT_UTILS_H
# define GIT_UTILS_H

# include <stddef.h>

typedef struct s_git_file
{
	char *sPath;
	char cStatus;
}	t_git_file;

t_git_file *arrGetGitFiles(size_t *piCount);
int iRunGitCommand(const char *sCmd);
void vcFreeGitFiles(t_git_file *arr, size_t iCount);

#endif

