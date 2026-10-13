import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../state/app_state.dart';
import 'appearance_dialog.dart';
import 'common.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _userNameFocus = FocusNode();
  var _hidePassword = true;

  @override
  void dispose() {
    _userNameController.dispose();
    _passwordController.dispose();
    _userNameFocus.dispose();
    super.dispose();
  }

  Future<void> _useDemoAccount() async {
    setState(() {
      _userNameController.text = demoMerchantUserName;
      _passwordController.text = demoMerchantPassword;
    });
    ref.read(appControllerProvider.notifier).clearError();
    await _submit();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await ref
        .read(appControllerProvider.notifier)
        .login(_userNameController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 56 : 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 64)
                        .clamp(0, double.infinity)
                        .toDouble(),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (wide) ...[
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 64),
                                child: _LoginIntroduction(colorScheme: scheme),
                              ),
                            ),
                          ],
                          SizedBox(
                            width: wide ? 430 : constraints.maxWidth - 48,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: AutofillGroup(
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!wide) ...[
                                          const BrandMark(),
                                          const SizedBox(height: 28),
                                        ],
                                        Text(
                                          '欢迎回来',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '登录已审批的商家账号以管理商品。',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                        ),
                                        if (appState.notice != null) ...[
                                          const SizedBox(height: 20),
                                          StatusBanner(
                                            message: appState.notice!,
                                            isError: false,
                                            onDismiss: ref
                                                .read(
                                                  appControllerProvider
                                                      .notifier,
                                                )
                                                .clearNotice,
                                          ),
                                        ],
                                        if (appState.error != null) ...[
                                          const SizedBox(height: 20),
                                          StatusBanner(
                                            key: const Key('login-error'),
                                            message: appState.error!,
                                            isError: true,
                                            onDismiss: ref
                                                .read(
                                                  appControllerProvider
                                                      .notifier,
                                                )
                                                .clearError,
                                          ),
                                        ],
                                        const SizedBox(height: 24),
                                        TextFormField(
                                          key: const Key('login-username'),
                                          controller: _userNameController,
                                          focusNode: _userNameFocus,
                                          enabled: !appState.busy,
                                          autofillHints: const [
                                            AutofillHints.username,
                                          ],
                                          textInputAction: TextInputAction.next,
                                          decoration: const InputDecoration(
                                            labelText: '商家账号',
                                            prefixIcon: Icon(
                                              Icons.person_outline_rounded,
                                            ),
                                          ),
                                          validator: (value) =>
                                              (value?.trim().isEmpty ?? true)
                                              ? '请输入商家账号'
                                              : null,
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          key: const Key('login-password'),
                                          controller: _passwordController,
                                          enabled: !appState.busy,
                                          obscureText: _hidePassword,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _submit(),
                                          decoration: InputDecoration(
                                            labelText: '密码',
                                            prefixIcon: const Icon(
                                              Icons.lock_outline_rounded,
                                            ),
                                            suffixIcon: IconButton(
                                              tooltip: _hidePassword
                                                  ? '显示密码'
                                                  : '隐藏密码',
                                              onPressed: () => setState(
                                                () => _hidePassword =
                                                    !_hidePassword,
                                              ),
                                              icon: Icon(
                                                _hidePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                          .visibility_off_outlined,
                                              ),
                                            ),
                                          ),
                                          validator: (value) =>
                                              (value?.isEmpty ?? true)
                                              ? '请输入密码'
                                              : null,
                                        ),
                                        const SizedBox(height: 24),
                                        FilledButton.icon(
                                          key: const Key('login-submit'),
                                          onPressed: appState.busy
                                              ? null
                                              : _submit,
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              48,
                                            ),
                                          ),
                                          icon: appState.busy
                                              ? const SizedBox.square(
                                                  dimension: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.login_rounded),
                                          label: Text(
                                            appState.busy ? '正在登录…' : '登录',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          key: const Key('fill-demo-account'),
                                          onPressed: appState.busy
                                              ? null
                                              : _useDemoAccount,
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(
                                              46,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.auto_fix_high_rounded,
                                          ),
                                          label: const Text('使用演示账号'),
                                        ),
                                        const SizedBox(height: 20),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: scheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.55),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '本原型仅在设备本地保存会话，不会保存密码。',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const Positioned(top: 20, right: 20, child: AppearanceButton()),
        ],
      ),
    );
  }
}

class _LoginIntroduction extends StatelessWidget {
  const _LoginIntroduction({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(height: 54),
        Container(
          width: 56,
          height: 6,
          decoration: BoxDecoration(
            color: colorScheme.secondary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '把门店的日常管理，\n放在一个清晰的桌面。',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.18,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '专注当前可用的总览与商品管理，数据保存在本机，适合比赛现场稳定演示。',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.55),
        ),
        const SizedBox(height: 42),
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Capability(icon: Icons.dashboard_outlined, label: '经营总览'),
            _Capability(icon: Icons.inventory_2_outlined, label: '商品 CRUD'),
            _Capability(icon: Icons.offline_bolt_outlined, label: '离线可用'),
          ],
        ),
      ],
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
