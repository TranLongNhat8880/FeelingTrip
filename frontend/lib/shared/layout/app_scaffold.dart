import 'travel_decoration.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.actions = const [],
    this.subtitle,
    this.titleWidget,
    this.bottom,
  });
  final String title;
  final bool showBack;
  final List<Widget> actions;
  final String? subtitle;
  final Widget? titleWidget;
  final PreferredSizeWidget? bottom;
  @override
  Size get preferredSize => Size.fromHeight(
    AppSizes.toolbarHeight + (bottom?.preferredSize.height ?? 0),
  );
  @override
  Widget build(BuildContext context) => AppBar(
    title:
        titleWidget ??
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),
    bottom: bottom,
    toolbarHeight: AppSizes.toolbarHeight,
    automaticallyImplyLeading: false,
    leadingWidth: AppSizes.toolbarHeight,
    leading: showBack && Navigator.canPop(context)
        ? Padding(
            padding: const EdgeInsets.all(4),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              tooltip: 'Quay lại',
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(hoverColor: Colors.transparent),
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
    this.subtitle,
    this.titleWidget,
    this.appBarBottom,
    this.scaffoldKey,
    this.drawer,
    this.floatingActionButton,
  });
  final Widget body;
  final String? title;
  final List<Widget> actions;
  final bool showBack;
  final bool scrollable;
  final Widget? bottomAction;
  final Widget? bottomNavigationBar;
  final EdgeInsetsGeometry padding;
  final String? subtitle;
  final Widget? titleWidget;
  final PreferredSizeWidget? appBarBottom;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final Widget? drawer;
  final Widget? floatingActionButton;
  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffoldKey,
    drawer: drawer,
    floatingActionButton: floatingActionButton,
    appBar: title == null
        ? null
        : AppTopBar(
            title: title!,
            titleWidget: titleWidget,
            subtitle: subtitle,
            bottom: appBarBottom,
            showBack: showBack,
            actions: actions,
          ),
    body: TravelBackdrop(
      child: SafeArea(
        child: scrollable
            ? SingleChildScrollView(padding: padding, child: body)
            : Padding(padding: padding, child: body),
      ),
    ),
    bottomNavigationBar: bottomAction == null
        ? bottomNavigationBar
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppActionBar(child: bottomAction!),
              ?bottomNavigationBar,
            ],
          ),
  );
}

class AppActionBar extends StatelessWidget {
  const AppActionBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          12,
          AppSizes.screenPadding,
          16,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}
