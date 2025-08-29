import 'package:flutter/material.dart';
import 'package:pet_shop/utils/contants.dart';

class MyButton extends StatelessWidget {
  final String text;
  final void Function()? onPressed;

  const MyButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
            style: ElevatedButton.styleFrom(

                backgroundColor: primaryColor,
                foregroundColor: Colors.white),
            onPressed: onPressed,
            child: Text(text))
      ],
    );
  }
}
