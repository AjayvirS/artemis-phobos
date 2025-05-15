/*
 *  netblocker.c  –  hybrid: check hostname in getaddrinfo,
 *                   enforce by IP in connect.
 *
 *  Rule file (NETBLOCKER_CONF env, default allowedList.cfg):
 *       # one per line
 *       services.gradle.org
 *       api.example.com
 *       192.168.0.0/16
 *       *                # wildcard
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <errno.h>
#include <pthread.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/socket.h>

/* --------------------- rule table --------------------- */
typedef struct rule_s {
    char *host;
    struct in6_addr cidr_addr;
    int cidr_bits;
    struct rule_s *next;
} rule_t;

static rule_t *rules = NULL;

/* ------------------ approved ip set ------------------ */
typedef struct ipnode { char ip[INET6_ADDRSTRLEN]; struct ipnode *next; } ipnode;
static ipnode *approved_ips = NULL;
static pthread_mutex_t ip_lock = PTHREAD_MUTEX_INITIALIZER;

static int ip_set_contains(const char *ip)
{
    pthread_mutex_lock(&ip_lock);
    for (ipnode *n = approved_ips; n; n = n->next)
        if (strcasecmp(n->ip, ip) == 0) { pthread_mutex_unlock(&ip_lock); return 1; }
    pthread_mutex_unlock(&ip_lock);
    return 0;
}

static void ip_set_insert(const char *ip)
{
    if (ip_set_contains(ip)) return;
    ipnode *n = malloc(sizeof *n);
    strcpy(n->ip, ip);
    pthread_mutex_lock(&ip_lock);
    n->next = approved_ips; approved_ips = n;
    pthread_mutex_unlock(&ip_lock);
}

/* -------------- helpers for CIDR match --------------- */
static int cidr_match(const struct in6_addr *addr,
                      const struct in6_addr *net, int bits)
{
    if (bits == 0) return 0;
    int full_bytes = bits / 8;
    int rem_bits   = bits % 8;
    if (memcmp(addr, net, full_bytes) != 0) return 0;
    if (rem_bits) {
        uint8_t mask = ~((1 << (8 - rem_bits)) - 1);
        return ((addr->s6_addr[full_bytes] & mask) ==
                (net ->s6_addr[full_bytes] & mask));
    }
    return 1;
}


/*  If s is "127.0.0.1"           → copy unchanged
 *           "::ffff:127.0.0.1"   → writes "127.0.0.1"
 *           "::1" or other IPv6  → copy unchanged
 *  Returns 0 on success, -1 on parse error                                */
static int from_canonical(const char *s, char out[INET6_ADDRSTRLEN])
{

    struct in6_addr v6;
    if (inet_pton(AF_INET6, s, &v6) == 1) {
        /* check for v4-mapped prefix ::ffff:0:0/96 */
        static const unsigned char v4map[12] =
            {0,0,0,0,0,0,0,0,0,0,0xff,0xff};
        if (memcmp(v6.s6_addr, v4map, 12) == 0) {
            snprintf(out, INET6_ADDRSTRLEN, "%u.%u.%u.%u",
                     v6.s6_addr[12], v6.s6_addr[13],
                     v6.s6_addr[14], v6.s6_addr[15]);
            return 0;
        }
        /* pure IPv6 → keep string as-is */
        strncpy(out, s, INET6_ADDRSTRLEN);
        return 0;
    }
    /* maybe already v4 text */
    struct in_addr v4;
    if (inet_pton(AF_INET, s, &v4) == 1) {
        strncpy(out, s, INET6_ADDRSTRLEN);
        return 0;
    }
    return -1;
}



/* -------------- parsing the rule file ---------------- */
static void load_rules(void)
{
    const char *conf = getenv("NETBLOCKER_CONF");
    if (!conf) conf = "allowedList.cfg";
    FILE *f = fopen(conf, "r");
    if (!f) { fprintf(stderr,"netblocker: cannot open %s\n",conf); return; }

    char line[256];
    while (fgets(line,sizeof line,f)) {
        char *hash = strchr(line,'#'); if (hash) *hash = 0;

        /* first token = host or CIDR or "*"              */
        char *tok = strtok(line, " \t\r\n"); if (!tok) continue;

        rule_t *r = calloc(1, sizeof *r);

        /* ------------- CIDR rule? ------------- */
        char *slash = strchr(tok, '/');
        if (slash) {
            *slash = 0;
            r->cidr_bits = atoi(slash + 1);
            inet_pton(AF_INET6, tok, &r->cidr_addr);
            r->host = strdup(tok);
        }
        else {
            /* normal host or numeric IP — normalise numeric forms */
            char plain[INET6_ADDRSTRLEN];
            if (from_canonical(tok, plain) == 0)
                r->host = strdup(plain);
            else
                r->host = strdup(tok);
        }

        /* prepend to list */
        r->next = rules;
        rules   = r;
    }
    fclose(f);
}



/* ------------------- allow check -------------------- */
static int host_allowed(const char *host)
{
    if (!host) return 0;
    for (rule_t *r = rules; r; r = r->next) {

        /* wildcard rule */
        if (strcasecmp(r->host, "*") == 0) return 1;

        /* suffix wildcard: rule starts with "*." */
        if (r->host[0] == '*' && r->host[1] == '.') {
            const char *suffix = r->host + 1;
            size_t hl = strlen(host), sl = strlen(suffix);
            if (hl >= sl && strcasecmp(host + hl - sl, suffix) == 0)
                return 1;
        }

        /* exact match */
        if (strcasecmp(host, r->host) == 0)
            return 1;
    }
    return 0;
}


static int ip_allowed(const char *ip)
{
    /* fast path: already ok */
    if (ip_set_contains(ip)) return 1;

    struct in6_addr addr6;
    inet_pton(AF_INET6, ip, &addr6);

    for (rule_t *r = rules; r; r = r->next) {
        if (strcasecmp(r->host,"*")==0) return 1;
        if (strchr(r->host,'.')==NULL && strchr(r->host,':')==NULL)
            continue;
        if (r->cidr_bits) {
            if (cidr_match(&addr6,&r->cidr_addr,r->cidr_bits))
                return 1;
        } else if (strcasecmp(r->host, ip)==0) {
            return 1;
        }
    }
    return 0;
}

/* ---------------- real functions -------------------- */
typedef int (*orig_getaddrinfo_f)(const char*,const char*,
                                  const struct addrinfo*,struct addrinfo**);
typedef int (*orig_connect_f)(int,const struct sockaddr*,socklen_t);
static orig_getaddrinfo_f real_gai   = NULL;
static orig_connect_f    real_conn = NULL;

/* ------------------- getaddrinfo -------------------- */
int getaddrinfo(const char *node, const char *svc,
                const struct addrinfo *hints, struct addrinfo **res)
{
    if (!real_gai)
        real_gai = (orig_getaddrinfo_f)dlsym(RTLD_NEXT,"getaddrinfo");

    if (node && !host_allowed(node)) {
        fprintf(stderr,"netblocker: BLOCK DNS %s\n", node);
        return EAI_FAIL;
    }
    int rc = real_gai(node,svc,hints,res);

    /* cache numeric IPs for allowed hostnames */
    if (rc==0 && node && host_allowed(node)) {
        for (struct addrinfo *ai=*res; ai; ai=ai->ai_next) {
            char canon[INET6_ADDRSTRLEN];
            getnameinfo(ai->ai_addr, ai->ai_addrlen, canon, sizeof canon,
                        NULL, 0, NI_NUMERICHOST | NI_NUMERICSERV);

            char plain[INET6_ADDRSTRLEN];
            if (from_canonical(canon, plain) == 0)
                ip_set_insert(plain);

        }
    }
    return rc;
}

/* --------------------- connect ---------------------- */
int connect(int fd, const struct sockaddr *sa, socklen_t len)
{
    if (!real_conn)
        real_conn = (orig_connect_f)dlsym(RTLD_NEXT,"connect");

    char canon[INET6_ADDRSTRLEN];
    getnameinfo(sa, len, canon, sizeof canon,
                NULL, 0, NI_NUMERICHOST | NI_NUMERICSERV);

    char plain[INET6_ADDRSTRLEN];
    if (from_canonical(canon, plain) != 0)
        strcpy(plain, canon);

    if (ip_set_contains(plain) || ip_allowed(plain))
        return real_conn(fd, sa, len);


    fprintf(stderr,"netblocker: BLOCK CONNECT %s\n", plain);
    errno = EACCES;
    return -1;
}

/* -------------- constructor: init once --------------- */
__attribute__((constructor))
static void init_netblocker(void) {
    load_rules();
    real_gai   = (orig_getaddrinfo_f)dlsym(RTLD_NEXT,"getaddrinfo");
    real_conn  = (orig_connect_f)   dlsym(RTLD_NEXT,"connect");
}
