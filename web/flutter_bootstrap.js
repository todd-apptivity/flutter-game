// Custom bootstrap. The two template tokens are substituted by
// `flutter build web`; `canvasKitBaseUrl` points CanvasKit at the copy in this
// deploy instead of the default gstatic.com CDN, so the page has no
// third-party runtime dependency.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
