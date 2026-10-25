/*
 * libvulkan_darkos.so - the Vulkan driver the loader sees, standing in for the real one a program
 * is to get: Arm's (libmali) or malisx2 (bmdhacks' Mesa driver over kbase).
 *
 * The two cannot both be drivers of one process: the one that is not Arm's gets no display.
 * Presenting through VK_KHR_display needs DRM master on the panel's card, libmali holds it once
 * it has enumerated its GPU, and malisx2's swapchain fails ("Failed to create KHR_display
 * surface" in RetroArch), whichever of the two is listed first. So the loader gets one driver,
 * this one, which loads one of the real ones and hands the loader its entry points.
 *
 * Which one, the first that says:
 *  1. DARKOS_VULKAN in the environment ("mali", "malisx2", or a driver library's path);
 *  2. a line "<program> = <driver>" in /etc/darkos/vulkan.conf, the program by the name of its
 *     executable (/proc/self/exe; armsx2-sdl, retroarch, ...);
 *  3. "default = <driver>" there;
 *  4. mali.
 * A driver that does not load is reported on stderr and libmali is taken instead.
 * DARKOS_VULKAN_DEBUG=1 reports the choice.
 */
#include <ctype.h>
#include <dlfcn.h>
#include <limits.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define EXPORT __attribute__((visibility("default")))

typedef void (*PFN_void)(void);
typedef int VkResult_;              /* VkResult, without the Vulkan headers */
typedef PFN_void (*PFN_gipa)(void *instance, const char *name);
typedef VkResult_ (*PFN_negotiate)(unsigned *version);

static const char *const kConf = "/etc/darkos/vulkan.conf";
static const char *const kMali = "/usr/lib/aarch64-linux-gnu/libmali.so";
static const char *const kMalisx2 = "/usr/lib/aarch64-linux-gnu/malisx2/libvulkan_malisx2.so";

static pthread_once_t once = PTHREAD_ONCE_INIT;
static PFN_gipa real_gipa;          /* vk_icdGetInstanceProcAddr */
static PFN_gipa real_gpdpa;         /* vk_icdGetPhysicalDeviceProcAddr, if it has one */
static PFN_negotiate real_negotiate;

static const char *library_of(const char *driver)
{
   if (!driver || !*driver || !strcmp(driver, "mali"))
      return kMali;
   if (!strcmp(driver, "malisx2"))
      return kMalisx2;
   return driver[0] == '/' ? driver : NULL;
}

static char *trim(char *s)
{
   while (isspace((unsigned char)*s))
      s++;
   char *e = s + strlen(s);
   while (e > s && isspace((unsigned char)e[-1]))
      *--e = '\0';
   return s;
}

/* The driver vulkan.conf gives this program, else its default, into buf ("" if neither). */
static void conf_choice(const char *program, char *buf, size_t size)
{
   char line[512], fallback[256] = "";
   buf[0] = '\0';
   FILE *f = fopen(kConf, "re");
   if (!f)
      return;
   while (fgets(line, sizeof(line), f)) {
      char *hash = strchr(line, '#');
      if (hash)
         *hash = '\0';
      char *eq = strchr(line, '=');
      if (!eq)
         continue;
      *eq = '\0';
      const char *key = trim(line), *value = trim(eq + 1);
      if (!*key || !*value)
         continue;
      if (!strcmp(key, program)) {
         snprintf(buf, size, "%s", value);
         break;
      }
      if (!strcmp(key, "default"))
         snprintf(fallback, sizeof(fallback), "%s", value);
   }
   fclose(f);
   if (!buf[0])
      snprintf(buf, size, "%s", fallback);
}

static void *open_driver(const char *path)
{
   void *h = dlopen(path, RTLD_NOW | RTLD_LOCAL);
   if (!h)
      return NULL;
   real_gipa = (PFN_gipa)dlsym(h, "vk_icdGetInstanceProcAddr");
   real_gpdpa = (PFN_gipa)dlsym(h, "vk_icdGetPhysicalDeviceProcAddr");
   real_negotiate = (PFN_negotiate)dlsym(h, "vk_icdNegotiateLoaderICDInterfaceVersion");
   if (!real_gipa) {
      dlclose(h);
      return NULL;
   }
   return h;
}

static void choose(void)
{
   char exe[PATH_MAX] = "", choice[256] = "";
   const ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);
   if (n > 0)
      exe[n] = '\0';
   const char *program = strrchr(exe, '/') ? strrchr(exe, '/') + 1 : exe;

   const char *env = getenv("DARKOS_VULKAN");
   const char *from = "default";
   if (env && *env) {
      snprintf(choice, sizeof(choice), "%s", env);
      from = "DARKOS_VULKAN";
   } else {
      conf_choice(program, choice, sizeof(choice));
      if (choice[0])
         from = "vulkan.conf";
   }

   const char *path = library_of(choice);
   if (!path) {
      fprintf(stderr, "darkos vulkan: unknown driver \"%s\" (%s); using mali\n", choice, from);
      path = kMali;
   }
   if (!open_driver(path)) {
      fprintf(stderr, "darkos vulkan: %s did not load (%s); using mali\n", path, dlerror());
      path = kMali;
      if (!open_driver(path))
         fprintf(stderr, "darkos vulkan: %s did not load either (%s)\n", path, dlerror());
   }
   const char *debug = getenv("DARKOS_VULKAN_DEBUG");
   if (path != kMali || (debug && *debug == '1'))
      fprintf(stderr, "darkos vulkan: %s for %s (%s)\n", path, program, from);
}

EXPORT VkResult_ vk_icdNegotiateLoaderICDInterfaceVersion(unsigned *version)
{
   pthread_once(&once, choose);
   if (real_negotiate)
      return real_negotiate(version);
   /* a driver without it speaks interface version 1 */
   if (*version > 1)
      *version = 1;
   return 0;
}

EXPORT PFN_void vk_icdGetInstanceProcAddr(void *instance, const char *name)
{
   pthread_once(&once, choose);
   return real_gipa ? real_gipa(instance, name) : NULL;
}

EXPORT PFN_void vk_icdGetPhysicalDeviceProcAddr(void *instance, const char *name)
{
   pthread_once(&once, choose);
   return real_gpdpa ? real_gpdpa(instance, name) : NULL;
}
