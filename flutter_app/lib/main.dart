import 'package:flutter/material.dart';

import 'src/agent_home_page.dart';
import 'src/studyos_theme.dart';

void main() {
  runApp(const StudyOsAgentApp());
}

class StudyOsAgentApp extends StatelessWidget {
  const StudyOsAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StudyOS Agent',
      theme: buildStudyOsTheme(),
      home: const AgentHomePage(),
    );
  }
}
