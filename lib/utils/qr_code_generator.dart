import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QRCodeGenerator extends StatelessWidget {
  final String url;

  QRCodeGenerator({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      child: QrImageView(
        data: url,
        version: QrVersions.auto,
        size: 200.0,
      ),
    );
  }
}