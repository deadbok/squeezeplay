/*
** Copyright 2007 Logitech. All Rights Reserved.
**
** This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.
*/


#ifndef JIVE_H
#define JIVE_H

#include "common.h"

#include <SDL_image.h>
#include <SDL_ttf.h>
#include <SDL_gfxPrimitives.h>
#include <SDL_rotozoom.h>


/* target frame rate 14 fps - may be tuned per platform, should be /2 */
#define JIVE_FRAME_RATE 14

/* print profile information for blit's */
#undef JIVE_PROFILE_BLIT

typedef unsigned int bool;
#define true 1
#define false !true

#define MIN(a,b) (((a)<(b))?(a):(b))
#define MAX(a,b) (((a)>(b))?(a):(b))

#define JIVE_COLOR_WHITE 0xFFFFFFFF
#define JIVE_COLOR_BLACK 0x000000FF

#define JIVE_XY_NIL -1
#define JIVE_WH_NIL 65535

typedef enum {
        JIVE_ALIGN_CENTER = 0,
        JIVE_ALIGN_LEFT,
        JIVE_ALIGN_RIGHT,
        JIVE_ALIGN_TOP,
        JIVE_ALIGN_BOTTOM,
        JIVE_ALIGN_TOP_LEFT,
        JIVE_ALIGN_TOP_RIGHT,
        JIVE_ALIGN_BOTTOM_LEFT,
        JIVE_ALIGN_BOTTOM_RIGHT,
} JiveAlign;


typedef enum {
	JIVE_LAYOUT_NORTH = 0,
	JIVE_LAYOUT_EAST,
	JIVE_LAYOUT_SOUTH,
	JIVE_LAYOUT_WEST,
	JIVE_LAYOUT_CENTER,
	JIVE_LAYOUT_NONE,
} JiveLayout;


typedef enum {
	JIVE_LAYER_FRAME		= 0x01,
	JIVE_LAYER_CONTENT		= 0x02,
	JIVE_LAYER_CONTENT_OFF_STAGE	= 0x04,
	JIVE_LAYER_CONTENT_ON_STAGE	= 0x08,
	JIVE_LAYER_ALL			= 0xFF,
} JiveLayer;


typedef enum {
	JIVE_EVENT_NONE			= 0x000000,

	JIVE_EVENT_SCROLL		= 0x000001,
	JIVE_EVENT_ACTION		= 0x000002,
        
	JIVE_EVENT_KEY_DOWN		= 0x000010,
	JIVE_EVENT_KEY_UP		= 0x000020,
	JIVE_EVENT_KEY_PRESS		= 0x000040,
	JIVE_EVENT_KEY_HOLD		= 0x000080,

	JIVE_EVENT_MOUSE_DOWN		= 0x000100,
	JIVE_EVENT_MOUSE_UP		= 0x000200,
	JIVE_EVENT_MOUSE_PRESS		= 0x000400,
	JIVE_EVENT_MOUSE_HOLD		= 0x000800,
    
	JIVE_EVENT_WINDOW_PUSH		= 0x001000,
	JIVE_EVENT_WINDOW_POP		= 0x002000,
	JIVE_EVENT_WINDOW_ACTIVE	= 0x004000,
	JIVE_EVENT_WINDOW_INACTIVE	= 0x008000,

	JIVE_EVENT_SHOW			= 0x010000,
	JIVE_EVENT_HIDE			= 0x020000,
	JIVE_EVENT_FOCUS_GAINED		= 0x040000,
	JIVE_EVENT_FOCUS_LOST		= 0x080000,

	JIVE_EVENT_SERVICE_JNT		= 0x100000,
	JIVE_EVENT_WINDOW_RESIZE	= 0x200000,
	JIVE_EVENT_SWITCH		= 0x400000,
	JIVE_EVENT_MOTION		= 0x800000,

	JIVE_EVENT_KEY_ALL		= ( JIVE_EVENT_KEY_DOWN | JIVE_EVENT_KEY_UP | JIVE_EVENT_KEY_PRESS | JIVE_EVENT_KEY_HOLD ),
	JIVE_EVENT_MOUSE_ALL		= ( JIVE_EVENT_MOUSE_DOWN | JIVE_EVENT_MOUSE_PRESS | JIVE_EVENT_MOUSE_HOLD ),
	JIVE_EVENT_VISIBLE_ALL		= ( JIVE_EVENT_SHOW | JIVE_EVENT_HIDE ),
	JIVE_EVENT_ALL			= 0xFFFFFF,
} JiveEventType;


typedef enum {
	JIVE_EVENT_UNUSED		= 0x0000,
	JIVE_EVENT_CONSUME		= 0x0001,
	JIVE_EVENT_QUIT			= 0x0002,
} JiveEventStatus;


typedef enum {
	JIVE_KEY_NONE			= 0x0000,
	JIVE_KEY_GO			= 0x0001,
	JIVE_KEY_BACK			= 0x0002,
	JIVE_KEY_UP			= 0x0004,
	JIVE_KEY_DOWN			= 0x0008,
	JIVE_KEY_LEFT			= 0x0010,
	JIVE_KEY_RIGHT			= 0x0020,
	JIVE_KEY_HOME			= 0x0040,
	JIVE_KEY_PLAY			= 0x0080,
	JIVE_KEY_ADD			= 0x0100,
	JIVE_KEY_PAUSE			= 0x0200,
	JIVE_KEY_REW			= 0x0400,
	JIVE_KEY_FWD			= 0x0800,
	JIVE_KEY_VOLUME_UP		= 0x1000,
	JIVE_KEY_VOLUME_DOWN		= 0x2000,
} JiveKey;


enum {
	JIVE_USER_EVENT_TIMER		= 0x00000001,
	JIVE_USER_EVENT_KEY_HOLD		= 0x00000002,
	JIVE_USER_EVENT_EVENT		= 0x00000003,
};


typedef struct jive_peer_meta JivePeerMeta;

typedef struct jive_inset JiveInset;

typedef struct jive_widget JiveWidget;

typedef struct jive_surface JiveSurface;

typedef struct jive_tile JiveTile;

typedef struct jive_event JiveEvent;

typedef struct jive_font JiveFont;


struct jive_peer_meta {
	size_t size;
	const char *magic;
	lua_CFunction gc;
};

struct jive_inset {
	Uint16 left, top, right, bottom;
};

struct jive_widget {
	SDL_Rect bounds;
	SDL_Rect preferred_bounds;
	JiveInset padding;
	JiveInset border;
	Uint8 layer;
};

struct jive_surface {
	Uint32 refcount;
	
	SDL_Surface *sdl;
	Sint16 offset_x, offset_y;	
};

struct jive_event {
	JiveEventType type;

	// FIXME i would like thie to be a union, but the tolua++
	// binding does not work.
	
	/* scroll */
	int scroll_rel;

	/* key */
	JiveKey key_code;

	/* mouse */
	Uint16 mouse_x;
	Uint16 mouse_y;
};

struct jive_font {
	Uint32 refcount;
	char *name;
	Uint16 size;

	// Specific font functions
	SDL_Surface *(*draw)(struct jive_font *, Uint32, const char *);
	int (*width)(struct jive_font *, const char *);
	void (*destroy)(struct jive_font *);

	// Data for specifc font types
	TTF_Font *ttf;
	int height;
	int ascend;

	struct jive_font *next;

	const char *magic;
};

struct jive_perfwarn {
	Uint32 screen;
	Uint32 layout;
	Uint32 draw;
	Uint32 event;
	Uint32 queue;
	Uint32 garbage;
};


/* Util functions */
void jive_print_stack(lua_State *L, char *str);
int jiveL_getframework(lua_State *L);
int jive_getmethod(lua_State *L, int index, char *method) ;
void *jive_getpeer(lua_State *L, int index, JivePeerMeta *peerMeta);
void jive_torect(lua_State *L, int index, SDL_Rect *rect);
void jive_rect_union(SDL_Rect *a, SDL_Rect *b, SDL_Rect *c);
void jive_rect_intersection(SDL_Rect *a, SDL_Rect *b, SDL_Rect *c);
int jive_find_file(const char *path, char *fullpath);
void jive_queue_event(JiveEvent *evt);


/* Surface functions */
JiveSurface *jive_surface_set_video_mode(Uint16 w, Uint16 h, Uint16 bpp);
JiveSurface *jive_surface_newRGB(Uint16 w, Uint16 h);
JiveSurface *jive_surface_newRGBA(Uint16 w, Uint16 h);
JiveSurface *jive_surface_ref(JiveSurface *srf);
JiveSurface *jive_surface_load_image(const char *path);
JiveSurface *jive_surface_load_image_data(const char *data, size_t len);
int jive_surface_save_bmp(JiveSurface *srf, const char *file);
void jive_surface_set_offset(JiveSurface *src, Sint16 x, Sint16 y);
void jive_surface_get_clip(JiveSurface *srf, SDL_Rect *r);
void jive_surface_set_clip(JiveSurface *srf, SDL_Rect *r);
void jive_surface_set_clip_arg(JiveSurface *srf, Uint16 x, Uint16 y, Uint16 w, Uint16 h);
void jive_surface_get_clip_arg(JiveSurface *srf, Uint16 *x, Uint16 *y, Uint16 *w, Uint16 *h);
void jive_surface_flip(JiveSurface *srf);
void jive_surface_blit(JiveSurface *src, JiveSurface *dst, Uint16 dx, Uint16 dy);
void jive_surface_blit_clip(JiveSurface *src, Uint16 sx, Uint16 sy, Uint16 sw, Uint16 sh,
			    JiveSurface* dst, Uint16 dx, Uint16 dy);
void jive_surface_get_size(JiveSurface *srf, Uint16 *w, Uint16 *h);
void jive_surface_free(JiveSurface *srf);

/* Encapsulated SDL_gfx functions */
JiveSurface *jive_surface_rotozoomSurface(JiveSurface *srf, double angle, double zoom, int smooth);
JiveSurface *jive_surface_zoomSurface(JiveSurface *srf, double zoomx, double zoomy, int smooth);
JiveSurface *jive_surface_shrinkSurface(JiveSurface *srf, int factorx, int factory);
void jive_surface_pixelColor(JiveSurface *srf, Sint16 x, Sint16 y, Uint32 col);
void jive_surface_hlineColor(JiveSurface *srf, Sint16 x1, Sint16 x2, Sint16 y, Uint32 color);
void jive_surface_vlineColor(JiveSurface *srf, Sint16 x, Sint16 y1, Sint16 y2, Uint32 color);
void jive_surface_rectangleColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col);
void jive_surface_boxColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col);
void jive_surface_lineColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col);
void jive_surface_aalineColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Uint32 col);
void jive_surface_circleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col);
void jive_surface_aacircleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col);
void jive_surface_filledCircleColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 r, Uint32 col);
void jive_surface_ellipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col);
void jive_surface_aaellipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col);
void jive_surface_filledEllipseColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rx, Sint16 ry, Uint32 col);
void jive_surface_pieColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 col);
void jive_surface_filledPieColor(JiveSurface *srf, Sint16 x, Sint16 y, Sint16 rad, Sint16 start, Sint16 end, Uint32 col);
void jive_surface_trigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col);
void jive_surface_aatrigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col);
void jive_surface_filledTrigonColor(JiveSurface *srf, Sint16 x1, Sint16 y1, Sint16 x2, Sint16 y2, Sint16 x3, Sint16 y3, Uint32 col);

/* Tile functions */
JiveTile *jive_tile_fill_color(Uint32 col);
JiveTile *jive_tile_load_image(const char *path);
JiveTile *jive_tile_load_tiles(char *path[9]);
JiveTile *jive_tile_load_vtiles(char *path[3]);
JiveTile *jive_tile_load_htiles(char *path[3]);
JiveTile *jive_tile_ref(JiveTile *tile);
void jive_tile_get_min_size(JiveTile *tile, Uint16 *w, Uint16 *h);
void jive_tile_free(JiveTile *tile);
void jive_tile_blit(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh);
void jive_tile_blit_centered(JiveTile *tile, JiveSurface *dst, Uint16 dx, Uint16 dy, Uint16 dw, Uint16 dh);


/* Font functions */
JiveFont *jive_font_load(const char *name, Uint16 size);
JiveFont *jive_font_ref(JiveFont *font);
void jive_font_free(JiveFont *font);
int jive_font_width(JiveFont *font, const char *str);
int jive_font_nwidth(JiveFont *font, const char *str, int len);
int jive_font_height(JiveFont *font);
int jive_font_ascend(JiveFont *font);
JiveSurface *jive_font_draw_text(JiveFont *font, Uint32 color, const char *str);
JiveSurface *jive_font_ndraw_text(JiveFont *font, Uint32 color, const char *str, size_t len);


/* C helper functions */
void jive_redraw(SDL_Rect *r);
void jive_pushevent(lua_State *L, JiveEvent *event);

void jive_widget_pack(lua_State *L, int index, JiveWidget *data);
int jive_widget_halign(JiveWidget *this, JiveAlign align, Uint16 width);
int jive_widget_valign(JiveWidget *this, JiveAlign align, Uint16 height);

int jive_style_int(lua_State *L, int index, const char *key, int def);
Uint32 jive_style_color(lua_State *L, int index, const char *key, Uint32 def, bool *is_set);
JiveSurface *jive_style_image(lua_State *L, int index, const char *key, JiveSurface *def);
JiveTile *jive_style_tile(lua_State *L, int index, const char *key, JiveTile *def);
JiveFont *jive_style_font(lua_State *L, int index, const char *key);
JiveAlign jive_style_align(lua_State *L, int index, char *key, JiveAlign def);
void jive_style_insets(lua_State *L, int index, char *key, JiveInset *inset);
int jive_style_array_size(lua_State *L, int index, char *key);
int jive_style_array_int(lua_State *L, int index, const char *array, int n, const char *key, int def);
JiveFont *jive_style_array_font(lua_State *L, int index, const char *array, int n, const char *key);
Uint32 jive_style_array_color(lua_State *L, int index, const char *array, int n, const char *key, Uint32 def, bool *is_set);

void jive_timer_dispatch_event(lua_State *L, void *param);


/* lua functions */
int jiveL_get_background(lua_State *L);
int jiveL_set_background(lua_State *L);
int jiveL_dispatch_event(lua_State *L);
int jiveL_dirty(lua_State *L);

int jiveL_init_audio(lua_State *L);
int jiveL_free_audio(lua_State *L);

int jiveL_event_new(lua_State *L);
int jiveL_event_tostring(lua_State* L);
int jiveL_event_get_type(lua_State *L);
int jiveL_event_get_scroll(lua_State *L);
int jiveL_event_get_keycode(lua_State *L);
int jiveL_event_get_mouse(lua_State *L);

int jiveL_widget_set_bounds(lua_State *L);
int jiveL_widget_get_bounds(lua_State *L);
int jiveL_widget_get_preferred_bounds(lua_State *L);
int jiveL_widget_get_border(lua_State *L);
int jiveL_widget_redraw(lua_State *L);
int jiveL_widget_dolayout(lua_State *L);

int jiveL_icon_get_preferred_bounds(lua_State *L);
int jiveL_icon_skin(lua_State *L);
int jiveL_icon_prepare(lua_State *L);
int jiveL_icon_layout(lua_State *L);
int jiveL_icon_animate(lua_State *L);
int jiveL_icon_draw(lua_State *L);
int jiveL_icon_gc(lua_State *L);

int jiveL_label_get_preferred_bounds(lua_State *L);
int jiveL_label_skin(lua_State *L);
int jiveL_label_prepare(lua_State *L);
int jiveL_label_layout(lua_State *L);
int jiveL_label_animate(lua_State *L);
int jiveL_label_draw(lua_State *L);
int jiveL_label_gc(lua_State *L);

int jiveL_textinput_get_preferred_bounds(lua_State *L);
int jiveL_textinput_skin(lua_State *L);
int jiveL_textinput_prepare(lua_State *L);
int jiveL_textinput_layout(lua_State *L);
int jiveL_textinput_draw(lua_State *L);
int jiveL_textinput_gc(lua_State *L);

int jiveL_menu_skin(lua_State *L);
int jiveL_menu_prepare(lua_State *L);
int jiveL_menu_layout(lua_State *L);
int jiveL_menu_iterate(lua_State *L);
int jiveL_menu_draw(lua_State *L);
int jiveL_menu_gc(lua_State *L);

int jiveL_textarea_get_preferred_bounds(lua_State *L);
int jiveL_textarea_skin(lua_State *L);
int jiveL_textarea_prepare(lua_State *L);
int jiveL_textarea_layout(lua_State *L);
int jiveL_textarea_draw(lua_State *L);
int jiveL_textarea_gc(lua_State *L);

int jiveL_window_skin(lua_State *L);
int jiveL_window_prepare(lua_State *L);
int jiveL_window_dolayout(lua_State *L);
int jiveL_popup_dolayout(lua_State *L);
int jiveL_window_iterate(lua_State *L);
int jiveL_popup_iterate(lua_State *L);
int jiveL_window_draw(lua_State *L);
int jiveL_popup_draw(lua_State *L);
int jiveL_window_event_handler(lua_State *L);
int jiveL_window_gc(lua_State *L);

int jiveL_slider_skin(lua_State *L);
int jiveL_slider_layout(lua_State *L);
int jiveL_slider_draw(lua_State *L);
int jiveL_slider_get_preferred_bounds(lua_State *L);
int jiveL_slider_gc(lua_State *L);

int jiveL_style_path(lua_State *L);
int jiveL_style_value(lua_State *L);
int jiveL_style_rawvalue(lua_State *L);
int jiveL_style_color(lua_State *L);
int jiveL_style_font(lua_State *L);

int jiveL_timer_add_timer(lua_State *L);
int jiveL_timer_remove_timer(lua_State *L);



#define JIVEL_STACK_CHECK_BEGIN(L) { int _sc = lua_gettop((L));
#define JIVEL_STACK_CHECK_ASSERT(L) assert(_sc == lua_gettop((L)));
#define JIVEL_STACK_CHECK_END(L) JIVEL_STACK_CHECK_ASSERT(L) }


#endif // JIVE_H
