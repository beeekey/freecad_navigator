#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gdk/gdk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Improved icon loading function
static GdkPixbuf* load_app_icon() {
  g_autoptr(GError) error = nullptr;
  GdkPixbuf* icon_pixbuf = nullptr;
  
  // Try multiple paths for the icon
  const gchar* icon_paths[] = {
    "assets/images/FreeCadExplorer_Logo.png",
    "data/flutter_assets/assets/images/FreeCadExplorer_Logo.png",
    "../data/flutter_assets/assets/images/FreeCadExplorer_Logo.png",
    "../../../../assets/images/FreeCadExplorer_Logo.png",
    nullptr
  };
  
  gchar* executable_path = g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path != nullptr) {
    gchar* executable_dir = g_path_get_dirname(executable_path);
    
    for (int i = 0; icon_paths[i] != nullptr; i++) {
      g_autofree gchar* full_path = g_build_filename(executable_dir, icon_paths[i], nullptr);
      icon_pixbuf = gdk_pixbuf_new_from_file(full_path, &error);
      if (icon_pixbuf != nullptr) {
        g_print("Loaded icon from: %s\n", full_path);
        break;
      }
      g_clear_error(&error);
    }
    
    g_free(executable_dir);
    g_free(executable_path);
  }
  
  // Fallback: try system icon theme
  if (icon_pixbuf == nullptr) {
    GtkIconTheme* icon_theme = gtk_icon_theme_get_default();
    icon_pixbuf = gtk_icon_theme_load_icon(icon_theme, "freecad_navigator", 48, GTK_ICON_LOOKUP_USE_BUILTIN, &error);
    if (icon_pixbuf != nullptr) {
      g_print("Loaded icon from system theme\n");
    }
  }
  
  return icon_pixbuf;
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  g_set_application_name("FreeCAD Navigator");

  // Set window icon using multiple methods for better compatibility
  gtk_window_set_icon_name(window, "freecad_navigator");
  
  // Load and set custom icon
  GdkPixbuf* icon_pixbuf = load_app_icon();
  if (icon_pixbuf != nullptr) {
    gtk_window_set_icon(window, icon_pixbuf);
    gtk_window_set_default_icon(icon_pixbuf);
    
    // Set as default icon for all windows
    GList* icon_list = nullptr;
    icon_list = g_list_append(icon_list, icon_pixbuf);
    gtk_window_set_default_icon_list(icon_list);
    g_list_free(icon_list);
    
    g_print("Window icon set successfully\n");
  } else {
    g_print("Failed to load window icon\n");
  }

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "FreeCAD Navigator");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "FreeCAD Navigator");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000 for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb), self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  g_set_prgname("FreeCAD Navigator");
  gdk_set_program_class("FreeCAD Navigator");

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
