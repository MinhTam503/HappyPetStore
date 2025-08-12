import 'dart:js' as js;

void sendOrderEmail({
  required String name,
  required String email,
  required String orderId,
  required String orderStatus,
}) {
  js.context.callMethod('sendOrderUpdate', [
    name,
    email,
    orderId,
    orderStatus,
  ]);
}
