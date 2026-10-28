import 'package:flutter/material.dart';

import 'profile_grid_screen.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TDB Online',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Manrope',
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const ProfileGridScreen(),
    );
  }
}
