import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// VNPay Payment WebView Screen
/// Hiển thị trang thanh toán VNPay trong WebView
class VnpayWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String returnUrl;
  final Function(Map<String, String> params)? onPaymentCallback;

  const VnpayWebViewScreen({
    Key? key,
    required this.paymentUrl,
    required this.returnUrl,
    this.onPaymentCallback,
  }) : super(key: key);

  @override
  State<VnpayWebViewScreen> createState() => _VnpayWebViewScreenState();
}

class _VnpayWebViewScreenState extends State<VnpayWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('🔄 VNPay WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            print('🌐 Page started loading: $url');
            setState(() {
              _isLoading = true;
              _error = null;
            });

            // Check if this is return URL
            if (url.startsWith(widget.returnUrl)) {
              print('✅ Detected return URL: $url');
              _handleReturnUrl(url);
            }
          },
          onPageFinished: (String url) {
            print('✅ Page finished loading: $url');
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ WebView error: ${error.description}');
            setState(() {
              _error = error.description;
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🔍 Navigation request: ${request.url}');
            
            // Intercept return URL
            if (request.url.startsWith(widget.returnUrl)) {
              print('🎯 Intercepted return URL, handling callback...');
              _handleReturnUrl(request.url);
              return NavigationDecision.prevent;
            }
            
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handleReturnUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      
      print('📦 VNPay callback params: $params');

      // Close WebView and return params
      if (widget.onPaymentCallback != null) {
        widget.onPaymentCallback!(params);
      }
      
      // Pop back to previous screen
      Navigator.of(context).pop(params);
    } catch (e) {
      print('❌ Error handling return URL: $e');
      setState(() {
        _error = 'Lỗi xử lý callback: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context)
                                    .colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            // Confirm before closing
            _showCloseConfirmation();
          },
        ),
        title: const Text(
          'Thanh toán VNPay',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // WebView
          if (_error == null)
            WebViewWidget(controller: _controller)
          else
            // Error view
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Có lỗi xảy ra',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error ?? 'Lỗi không xác định',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _error = null;
                            });
                            _initializeWebView();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                    .colorScheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (_isLoading && _error == null)
            Container(
              color: Colors.white.withOpacity(0.8),
              child:  Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context)
                                    .colorScheme.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Đang tải trang thanh toán...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCloseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy thanh toán?'),
        content: const Text(
          'Bạn có chắc chắn muốn hủy giao dịch thanh toán này không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tiếp tục thanh toán'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close WebView
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Hủy thanh toán'),
          ),
        ],
      ),
    );
  }
}
