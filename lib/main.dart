import 'dart:async';

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

// ignore: implementation_imports
import 'package:analyzer/src/analysis_options/analysis_options_provider.dart';
// ignore: implementation_imports
import 'package:analyzer/src/dart/analysis/driver_based_analysis_context.dart';

import 'package:build_runner_hook/build_runner_manager.dart';

final plugin = BuildRunnerHook();

final class BuildRunnerHook extends Plugin {
  final BuildRunnerManager _runnerHook = BuildRunnerManager();

  @override
  String get name => "Build Runner Hook";

  @override
  FutureOr<void> register(PluginRegistry registry) {
    registry.registerWarningRule(
      BootstrapBuildRunner(_runnerHook),
    );
  }

  @override
  FutureOr<void> shutDown() {
    _runnerHook.stop();
    return super.shutDown();
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
    registry.addPartDirective(this, visitor);
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  const _Visitor(this._runnerHook, this.context);

  final BuildRunnerManager _runnerHook;

  final RuleContext context;

  @override
  void visitPartDirective(PartDirective node) {
    if (_runnerHook.running) return;

    final packageRootPath = context.package?.root.path ?? "";

    try {
      final collection = AnalysisContextCollection(
        includedPaths: [packageRootPath],
      );
      final analysisOptionsContext =
          collection.contextFor(packageRootPath) as DriverBasedAnalysisContext;

      final sourceProvider = analysisOptionsContext.driver.sourceFactory;
      final resourceProvider = analysisOptionsContext.driver.resourceProvider;

      final provider = AnalysisOptionsProvider(sourceProvider);

      final path = "$packageRootPath/analysis_options.yaml";
      final yamlMap = provider.getOptionsFromFile(
        resourceProvider.getFile(path),
      );

      _runnerHook.log(path);
      _runnerHook.log(yamlMap.toString());

      _runnerHook.start(packageRootPath);
    } catch (e) {
      _runnerHook.log(e.toString());
    }
  }
}
