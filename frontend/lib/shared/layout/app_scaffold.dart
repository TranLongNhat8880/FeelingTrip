import 'travel_decoration.dart';
import '../../core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import '../buttons/app_icon_button.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions = const [],
  });
  final String title;
  final bool showBack;
  final List<Widget> actions;
  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.toolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title),
    toolbarHeight: AppSizes.toolbarHeight,
    automaticallyImplyLeading: false,
    leadingWidth: AppSizes.toolbarHeight,
    leading: showBack && Navigator.canPop(context)
        ? Padding(
            padding: const EdgeInsets.all(4),
            child: AppIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
            ),
          )
        : null,
    actions: [...actions, const SizedBox(width: 16)],
  );
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions = const [],
    this.showBack = true,
    this.scrollable = false,
    this.bottomAction,
    this.bottomNavigationBar,
    this.padding = const EdgeInsets.all(AppSizes.screenPadding),
  });
  final Widget body;
  final String? title;
  final List<Widget> actions;
  final bool showBack;
  final bool scrollable;
  final Widget? bottomAction;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: title == null
        ? null
        : AppTopBar(title: title!, showBack: showBack, actions: actions),
    body: TravelBackdrop(
      child: SafeArea(
        child: scrollable
            ? SingleChildScrollView(padding: padding, child: body)
            : Padding(padding: padding, child: body),
      ),
    ),
    bottomNavigationBar: bottomAction == null
        ? bottomNavigationBar
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.screenPadding,
                12,
                AppSizes.screenPadding,
                16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [bottomAction!, ?bottomNavigationBar],
              ),
            ),
          ),
  );
}
