import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

class PortalViewerPage extends StatefulWidget {
  final Uri feewPath;

  const PortalViewerPage({super.key, required this.feewPath});

  @override
  State<PortalViewerPage> createState() => _PortalViewerPageState();
}

class _PortalViewerPageState extends State<PortalViewerPage> {
  InAppWebViewController? _rootController;
  final List<int> _popupWindowIds = [];
  final Map<int, InAppWebViewController> _popupControllers = {};

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<bool> _handleBack() async {
    if (_popupWindowIds.isNotEmpty) {
      final int lastId = _popupWindowIds.last;
      setState(() {
        _popupControllers.remove(lastId);
        _popupWindowIds.remove(lastId);
      });
      return false;
    }

    if (_rootController != null && await _rootController!.canGoBack()) {
      await _rootController!.goBack();
      return false;
    }

    return true; // allow system back to close page
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                key: const ValueKey('root'),
                initialUrlRequest: URLRequest(url: WebUri.uri(widget.feewPath)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                javaScriptCanOpenWindowsAutomatically: true,
                supportMultipleWindows: true,
                mediaPlaybackRequiresUserGesture: false,
                allowFileAccess: true,
                allowContentAccess: true,
              ),
                onWebViewCreated: (controller) {
                  _rootController = controller;
                },
                onCreateWindow: (controller, action) async {
                  final id = action.windowId;
                  setState(() {
                    _popupWindowIds.add(id);
                  });
                  return true;
                },
                androidOnPermissionRequest:
                    (controller, origin, resources) async {
                  return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT,
                  );
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) return NavigationActionPolicy.CANCEL;

                  final scheme = (uri.scheme).toLowerCase();
                  const internalSchemes = [
                    'http',
                    'https',
                    'about',
                    'srcdoc',
                    'blob',
                    'data',
                    'javascript',
                    'file'
                  ];
                  if (internalSchemes.contains(scheme)) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  final bool launched = await _launchExternal(uri);
                  if (!launched) {
                    await controller.stopLoading();
                  }
                  return NavigationActionPolicy.CANCEL;
                },
              ),
              for (final windowId in _popupWindowIds)
                InAppWebView(
                  key: ValueKey('popup_$windowId'),
                  windowId: windowId,
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true,
                    supportMultipleWindows: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowFileAccess: true,
                    allowContentAccess: true,
                  ),
                  onWebViewCreated: (controller) {
                    _popupControllers[windowId] = controller;
                  },
                  onCloseWindow: (controller) {
                    setState(() {
                      _popupControllers.remove(windowId);
                      _popupWindowIds.remove(windowId);
                    });
                  },
                  androidOnPermissionRequest:
                      (controller, origin, resources) async {
                    return PermissionRequestResponse(
                      resources: resources,
                      action: PermissionRequestResponseAction.GRANT,
                    );
                  },
                  shouldOverrideUrlLoading:
                      (controller, navigationAction) async {
                    final uri = navigationAction.request.url;
                    if (uri == null) return NavigationActionPolicy.CANCEL;

                    final scheme = (uri.scheme).toLowerCase();
                    const internalSchemes = [
                      'http',
                      'https',
                      'about',
                      'srcdoc',
                      'blob',
                      'data',
                      'javascript',
                      'file'
                    ];

                    if (internalSchemes.contains(scheme)) {
                      return NavigationActionPolicy.ALLOW;
                    }

                    final bool launched = await _launchExternal(uri);
                    if (!launched) {
                      await controller.stopLoading();
                    }
                    return NavigationActionPolicy.CANCEL;
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _launchExternal(Uri uri) async {
    try {
      if (uri.scheme == 'intent') {
        final String? fallback = Uri.decodeComponent(
          uri.queryParameters['S.browser_fallback_url'] ?? '',
        );
        if (fallback != null && fallback.isNotEmpty) {
          return launchUrl(Uri.parse(fallback),
              mode: LaunchMode.externalApplication);
        }
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<void> _requestPermissions() async {
    final List<Permission> perms = [
      Permission.camera,
      Permission.microphone,
      Permission.photos,
      Permission.videos,
      Permission.storage,
      Permission.notification,
    ];
    for (final perm in perms) {
      final status = await perm.status;
      if (!status.isGranted) {
        await perm.request();
      }
    }
  }
}
