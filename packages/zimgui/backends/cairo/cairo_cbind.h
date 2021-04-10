#include <cairo.h>
#include <pango/pangocairo.h>
#include <gtk/gtk.h>

#ifdef cairo_implementation
	#define IMPL(...) __VA_ARGS__
	#define IMPLONLY(...) __VA_ARGS__
#else
	#define IMPL(...) ;
	#define IMPLONLY(...)
#endif

typedef struct StructZigOpaque ZigOpaque;

IMPLONLY(

gboolean zig_on_draw_event(GtkWidget *widget, cairo_t *cr, gpointer user_data);
gboolean zig_on_resize_event(GtkWidget *widget, GdkRectangle *allocation, gpointer data);

gboolean zig_button_press_event(GtkWidget *widget, GdkEventButton *event, gpointer data);
gboolean zig_button_release_event(GtkWidget *widget, GdkEventButton *event, gpointer data);
gboolean zig_motion_notify_event(GtkWidget *widget, GdkEventMotion *event, gpointer data);

gboolean zig_scroll_event(GtkWidget *widget, GdkEventScroll *event, gpointer data);

gboolean zig_key_event(GtkWidget *widget, GdkEventKey *event, gpointer data);
void zig_on_commit_event(GtkIMContext *context, char *str, gpointer data);

static void destroy(GtkWidget *widget, gpointer data) {
    gtk_main_quit ();
}


// https://developer.gnome.org/gtk3/stable/GtkIMContext.html
void zig_on_commit_event(GtkIMContext *context, gchar *str, gpointer user_data);
gboolean zig_on_delete_surrounding_event(GtkIMContext *context, gint offset, gint n_chars, gpointer user_data);
void zig_on_preedit_changed_event(GtkIMContext *context, gpointer user_data);
gboolean zig_on_retrieve_surrounding_event(GtkIMContext *context, gpointer user_data);

)

gboolean get_scroll_delta(GdkEventScroll *event, gdouble *out_x, gdouble *out_y) IMPL({
	if(event->direction == GDK_SCROLL_UP) {
		*out_x = 0;
		*out_y = -1;
		return TRUE;
	}else if(event->direction == GDK_SCROLL_DOWN) {
		*out_x = 0;
		*out_y = 1;
		return TRUE;
	}else if(event->direction == GDK_SCROLL_LEFT) {
		*out_x = -1;
		*out_y = 0;
		return TRUE;
	}else if(event->direction == GDK_SCROLL_RIGHT) {
		*out_x = 1;
		*out_y = 0;
		return TRUE;
	}else if(event->direction == GDK_SCROLL_SMOOTH) {
		// if(!gdk_event_get_scroll_deltas((GdkEvent*)event, out_x, out_y)) return FALSE;
		*out_x = event->delta_x;
		*out_y = event->delta_y;
		return TRUE;
	}else{
		return FALSE;
	}
})

// it has bitfields https://developer.gnome.org/gdk3/unstable/gdk3-Event-Structures.html#GdkEventKey
void extract_key_event_fields(GdkEventKey* event, GdkEventType* out_event_type, guint* out_keyval, guint* out_modifiers) IMPL({
	*out_event_type = event->type;
	*out_keyval = event->keyval;
	*out_modifiers = event->state;
})

IMPLONLY(

typedef struct {
	void* zig;
	GtkWidget* darea;
} OpaqueData;

);

int start_gtk(int argc, char *argv[], void* zig_ptr)
IMPL({
	gtk_init(&argc, &argv);

	GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);

	gtk_widget_add_events(window, GDK_KEY_PRESS_MASK);
	gtk_widget_add_events(window, GDK_KEY_RELEASE_MASK);
	
	GtkIMContext *im_context = gtk_im_multicontext_new();
	GdkWindow *gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
	gtk_im_context_set_client_window(im_context, gdk_window);

	GtkWidget *darea = gtk_drawing_area_new();
	gtk_container_add(GTK_CONTAINER(window), darea);

	OpaqueData user_data = { .zig = zig_ptr, .darea = darea };
	OpaqueData* user_ptr = (gpointer)(&user_data);

	g_signal_connect(G_OBJECT(darea), "draw", G_CALLBACK(zig_on_draw_event), user_ptr); 
	g_signal_connect(G_OBJECT(darea), "size_allocate", G_CALLBACK(zig_on_resize_event), user_ptr);
	g_signal_connect(window, "destroy", G_CALLBACK(destroy), user_ptr);

	g_signal_connect(G_OBJECT(darea), "button_press_event", G_CALLBACK(zig_button_press_event), user_ptr);
	g_signal_connect(G_OBJECT(darea), "button_release_event", G_CALLBACK(zig_button_release_event), user_ptr);
	g_signal_connect(G_OBJECT(darea), "motion_notify_event", G_CALLBACK(zig_motion_notify_event), user_ptr);
	g_signal_connect(G_OBJECT(darea), "scroll_event", G_CALLBACK(zig_scroll_event), user_ptr);
	gtk_widget_set_events (darea, 0
		| GDK_LEAVE_NOTIFY_MASK
		| GDK_BUTTON_PRESS_MASK
		| GDK_BUTTON_RELEASE_MASK
		| GDK_POINTER_MOTION_MASK
		| GDK_SCROLL_MASK
		| GDK_SMOOTH_SCROLL_MASK
	);

	// https://developer.gnome.org/gtk3/stable/GtkWidget.html#GtkWidget-key-press-event
	g_signal_connect(G_OBJECT(window), "key_press_event", G_CALLBACK(zig_key_event), user_ptr);
	g_signal_connect(G_OBJECT(window), "key_release_event", G_CALLBACK(zig_key_event), user_ptr);

	// https://developer.gnome.org/gtk3/stable/GtkIMContext.html
	g_signal_connect(im_context, "commit", G_CALLBACK(zig_on_commit_event), user_ptr);
	//g_signal_connect(im_context, "delete-surrounding", G_CALLBACK(zig_delete_surrounding_event), user_ptr);
	//g_signal_connect(im_context, "preedit-changed", G_CALLBACK(zig_preedit_changed_event), user_ptr);
	//g_signal_connect(im_context, "retrieve-surrounding", G_CALLBACK(zig_retrieve_surrounding_event), user_ptr);
	//TODO specify location of IME screen

	gtk_window_set_position(GTK_WINDOW(window), GTK_WIN_POS_CENTER);
	gtk_window_set_default_size(GTK_WINDOW(window), 400, 90); 
	gtk_window_set_title(GTK_WINDOW(window), "GTK window");

	gtk_widget_show_all(window); 
	gtk_im_context_focus_in(im_context);

	gtk_main();

	return 0;
})