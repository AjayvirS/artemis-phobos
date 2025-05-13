#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <netdb.h>

typedef int (*orig_getaddrinfo_f)(const char *, const char *, const struct addrinfo *, struct addrinfo **);
static orig_getaddrinfo_f orig_getaddrinfo;

typedef struct {
    char *node;
    char *service;
} allowed_entry_t;

static allowed_entry_t *allowed = NULL;
static size_t allowed_count = 0;

__attribute__((constructor))
static void load_allowed_list(void) {
    const char *conf = getenv("NETBLOCKER_CONF");
    if (!conf) conf = "allowedList.cfg";
    FILE *f = fopen(conf, "r");
    if (!f) {
        fprintf(stderr, "netblocker: unable to open %s\n", conf);
        return;
    }
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        char *p = strchr(line, '#');
        if (p) *p = '\0';
        char *node = strtok(line, " \t\r\n:");
        char *port = strtok(NULL, " \t\r\n");
        if (node && port) {
            allowed = realloc(allowed, (allowed_count+1) * sizeof(allowed_entry_t));
            allowed[allowed_count].node = strdup(node);
            allowed[allowed_count].service = strdup(port);
            allowed_count++;
        }
    }
    fclose(f);
    orig_getaddrinfo = (orig_getaddrinfo_f)dlsym(RTLD_NEXT, "getaddrinfo");
}

static int is_allowed(const char *node, const char *service) {
    if (!node || !service) return 0;
    for (size_t i = 0; i < allowed_count; i++) {
        if (strcmp(node, allowed[i].node) == 0 && strcmp(service, allowed[i].service) == 0) {
            return 1;
        }
    }
    return 0;
}

int getaddrinfo(const char *node, const char *service,
                const struct addrinfo *hints, struct addrinfo **res) {
    if (!orig_getaddrinfo) {
        orig_getaddrinfo = (orig_getaddrinfo_f)dlsym(RTLD_NEXT, "getaddrinfo");
        if (!orig_getaddrinfo) exit(1);
    }
    if (!is_allowed(node, service)) {
        fprintf(stderr, "netblocker: blocking DNS lookup %s:%s\n", node, service);
        return EAI_NONAME;
    }
    return orig_getaddrinfo(node, service, hints, res);
}
