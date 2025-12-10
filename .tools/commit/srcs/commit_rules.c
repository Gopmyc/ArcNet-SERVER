#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cJSON.h"
#include "auto_commit.h"

static t_commit_rule *gRules = NULL;
static size_t gRuleCount = 0;

void vFreeCommitRules(void) {
	if (!gRules) return;
	for (size_t i = 0; i < gRuleCount; i++) {
		free((char*)gRules[i].sPathPrefix);
		for (int t = 0; t < 4; t++) {
			free((char*)gRules[i].actions[t].sTag);
			free((char*)gRules[i].actions[t].sEmoji);
			free((char*)gRules[i].actions[t].sDesc);
		}
	}
	free(gRules);
	gRules = NULL;
	gRuleCount = 0;
}

static char *strDup(const char *s) {
	if (!s) return NULL;
	size_t len = strlen(s) + 1;
	char *p = malloc(len);
	if (!p) return NULL;
	memcpy(p, s, len);
	return p;
}

int bLoadCommitRules(const char *sFile) {
	vFreeCommitRules();

	FILE *f = fopen(sFile, "rb");
	if (!f) return 0;

	fseek(f, 0, SEEK_END);
	long size = ftell(f);
	fseek(f, 0, SEEK_SET);

	char *text = malloc(size + 1);
	if (!text) { fclose(f); return 0; }

	fread(text, 1, size, f);
	text[size] = '\0';
	fclose(f);

	cJSON *root = cJSON_Parse(text);
	free(text);

	if (!root || !cJSON_IsArray(root)) {
		cJSON_Delete(root);
		return 0;
	}

	gRuleCount = cJSON_GetArraySize(root);
	gRules = calloc(gRuleCount, sizeof(t_commit_rule));
	if (!gRules) {
		cJSON_Delete(root);
		return 0;
	}

	for (size_t i = 0; i < gRuleCount; i++) {
		cJSON *item = cJSON_GetArrayItem(root, i);
		if (!cJSON_IsObject(item)) continue;

		cJSON *prefix = cJSON_GetObjectItem(item, "path");
		gRules[i].sPathPrefix = strDup(prefix && prefix->valuestring ? prefix->valuestring : "");

		cJSON *acts = cJSON_GetObjectItem(item, "actions");
		if (acts && cJSON_IsObject(acts)) {
			const char *names[4] = { "add", "modify", "delete", "rename" };
			for (int t = 0; t < 4; t++) {
				cJSON *entry = cJSON_GetObjectItem(acts, names[t]);
				if (entry && cJSON_IsObject(entry)) {
					cJSON *tag   = cJSON_GetObjectItem(entry, "tag");
					cJSON *emoji = cJSON_GetObjectItem(entry, "emoji");
					cJSON *desc  = cJSON_GetObjectItem(entry, "desc");

					gRules[i].actions[t].sTag   = strDup(tag   && tag->valuestring ? tag->valuestring : FALLBACK_TAG);
					gRules[i].actions[t].sEmoji = strDup(emoji && emoji->valuestring ? emoji->valuestring : FALLBACK_EMOJI);
					gRules[i].actions[t].sDesc  = strDup(desc  && desc->valuestring ? desc->valuestring : FALLBACK_DESC);
				} else {
					gRules[i].actions[t].sTag   = FALLBACK_TAG;
					gRules[i].actions[t].sEmoji = FALLBACK_EMOJI;
					gRules[i].actions[t].sDesc  = FALLBACK_DESC;
				}
			}
		}
	}
	cJSON_Delete(root);
	return 1;
}

const t_commit_rule *psFindDynamicRule(const char *path) {
	for (size_t i = 0; i < gRuleCount; i++) {
		if (strncmp(path, gRules[i].sPathPrefix, strlen(gRules[i].sPathPrefix)) == 0)
			return &gRules[i];
	}
	return NULL;
}
