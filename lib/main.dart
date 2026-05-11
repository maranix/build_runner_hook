import 'dart:async';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'package:build_runner_hook/build_runner_manager.dart';
import 'package:build_runner_hook/utils.dart';

final plugin = BuildRunnerHook();

final class BuildRunnerHook extends Plugin {
  final BuildRunnerManager _runnerHook = BuildRunnerManager(
    TempDirectory.resolveFor("./build_runner_hook"),
  );

  @override
  String get name => "Build Runner Hook";

  @override
  FutureOr<void> start() async {
    await _runnerHook.init();
    return await super.start();
  }

  @override
  FutureOr<void> register(PluginRegistry registry) {
    registry.registerWarningRule(
      BootstrapBuildRunner(_runnerHook),
    );
  }

  @override
  FutureOr<void> shutDown() async {
    await _runnerHook.dispose();
    return await super.shutDown();
  }
}

final class BootstrapBuildRunner extends AnalysisRule {
  BootstrapBuildRunner(this._runnerHook)
    : super(
        name: "auto_start",
        description: "Enable or disable auto start of build_runner",
      );

  final BuildRunnerManager _runnerHook;

  static const LintCode _code = LintCode("auto_start", "");

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(_runnerHook, context);
    registry.addCompilationUnit(this, visitor);
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  const _Visitor(this._runnerHook, this.context);

  final BuildRunnerManager _runnerHook;

  final RuleContext context;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    if (!_runnerHook.isInitialized) return;

    final fragment = node.declaredFragment;
    if (fragment == null) return;

    final ctx = fragment.element.session.analysisContext.contextRoot;
    _runnerHook.registerContext(ctx);
  }
}
