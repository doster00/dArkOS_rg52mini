/*
 * drastic-hotkey.so: DraStic's menu on Home+X, as RetroArch has its menu,
 * instead of L3 alone. L3 is the switch under the RG52 Mini's left stick, and
 * it closes by itself when the stick is pushed hard. nds.sh loads this library
 * into DraStic with LD_PRELOAD.
 *
 * DraStic reads the pad as SDL events. This wraps SDL_PollEvent for the
 * rk3562-joystick (Home is the kernel's BTN_MODE, SDL's button 10):
 * - Home+X is passed on as L3, the button drastic.cfg names for the menu.
 * - A real L3 is dropped.
 * - While Home is held, no button reaches the game.
 * - Home tapped alone is passed on as a tap, so it still swaps the screens.
 * A button released while Home is held is passed on if its press was, so
 * none is left pressed.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <SDL2/SDL.h>

#define BTN_X    2
#define BTN_HOME 10
#define BTN_L3   11

static int (*real_poll)(SDL_Event *);
static SDL_Event pending[2];
static int npending;
/* an event held back to the next frame, so that DraStic sees a press and
 * its release in different frames */
static SDL_Event later;
static int later_set, later_due;
static SDL_JoystickID pad = -1;
static int home_held, home_used, menu_held;
static Uint32 passed;  /* the buttons whose press DraStic got */

static int is_pad(SDL_JoystickID id)
{
    SDL_Joystick *j;
    const char *name;

    if (id == pad)
        return 1;
    j = SDL_JoystickFromInstanceID(id);
    name = j ? SDL_JoystickName(j) : NULL;
    if (name && strcmp(name, "rk3562-joystick") == 0) {
        pad = id;
        return 1;
    }
    return 0;
}

static void make(SDL_Event *out, const SDL_Event *e, Uint8 button, int down)
{
    *out = *e;
    out->jbutton.type = down ? SDL_JOYBUTTONDOWN : SDL_JOYBUTTONUP;
    out->jbutton.button = button;
    out->jbutton.state = down ? SDL_PRESSED : SDL_RELEASED;
}

static void push(const SDL_Event *e, Uint8 button, int down)
{
    make(&pending[npending++], e, button, down);
}

/* what DraStic gets for a button event of the pad */
static void filter(const SDL_Event *e)
{
    int down = e->type == SDL_JOYBUTTONDOWN;
    Uint8 b = e->jbutton.button;
    Uint32 bit = b < 32 ? 1u << b : 0;

    switch (b) {
    case BTN_L3:
        return;
    case BTN_HOME:
        if (down) {
            home_held = 1;
            home_used = 0;
        } else {
            home_held = 0;
            if (!home_used) {
                push(e, BTN_HOME, 1);
                make(&later, e, BTN_HOME, 0);
                later_set = 1;
                later_due = 0;
            }
        }
        return;
    case BTN_X:
        if (down && home_held) {
            home_used = 1;
            menu_held = 1;
            push(e, BTN_L3, 1);
            return;
        }
        if (!down && menu_held) {
            menu_held = 0;
            push(e, BTN_L3, 0);
            return;
        }
        break;
    }
    if (down) {
        if (home_held) {
            home_used = 1;
            return;
        }
        passed |= bit;
    } else {
        if (!(passed & bit))
            return;
        passed &= ~bit;
    }
    push(e, b, down);
}

int SDL_PollEvent(SDL_Event *ev)
{
    SDL_Event e;

    if (!real_poll)
        real_poll = (int (*)(SDL_Event *))dlsym(RTLD_NEXT, "SDL_PollEvent");
    for (;;) {
        if (npending) {
            if (ev) {
                *ev = pending[0];
                if (--npending)
                    pending[0] = pending[1];
            }
            return 1;
        }
        if (later_set && later_due) {
            if (ev) {
                *ev = later;
                later_set = 0;
            }
            return 1;
        }
        if (!ev)
            return real_poll(NULL);
        if (!real_poll(&e)) {
            /* the queue is empty: this frame's events are done */
            if (later_set)
                later_due = 1;
            return 0;
        }
        if ((e.type == SDL_JOYBUTTONDOWN || e.type == SDL_JOYBUTTONUP) &&
            is_pad(e.jbutton.which)) {
            filter(&e);
            continue;
        }
        *ev = e;
        return 1;
    }
}
