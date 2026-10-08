import 'package:flutter/material.dart';

Widget mapTile(String url, VoidCallback onError) => Image.network(
  url,
  fit: BoxFit.fill,
  errorBuilder: (_, error, stack) {
    onError();
    return const ColoredBox(color: Color(0xFFF1F5F9));
  },
);
