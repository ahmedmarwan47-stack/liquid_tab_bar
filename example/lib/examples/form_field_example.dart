import 'package:flutter/material.dart';
import 'package:liquid_tab_bar/liquid_tab_bar.dart';

import 'showcase_content.dart';

class FormFieldExample extends StatefulWidget {
  const FormFieldExample({super.key});

  @override
  State<FormFieldExample> createState() => _FormFieldExampleState();
}

class _FormFieldExampleState extends State<FormFieldExample> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: const Text('Text Form Field')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          children: [
            Text(
              'Try the keyboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the field and type to see how the page and tab bar behave with the keyboard open.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              onTapOutside: (event) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Your message',
                hintText: 'Type something…',
                prefixIcon: Icon(Icons.edit_rounded),
                border: OutlineInputBorder(),
              ),
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            ),
            const SizedBox(height: 24),
            for (var index = 1; index <= 8; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notes_rounded),
                title: Text('Scrollable item $index'),
                subtitle: const Text(
                  'Scroll the page while the keyboard is open.',
                ),
              ),
          ],
        ),
        bottomNavigationBar: LiquidTabBar(
          key: const ValueKey('form-field-bar'),
          liftAboveKeyboard: true,
          shrinkOnScroll: false,
          selectedIndex: _selected,
          onSelected: (index) => setState(() => _selected = index),
          separateAction: LiquidTabAction.search(hintText: 'Search…'),
          items: showcaseItems(),
        ),
      );
}
