using System.Collections.Generic;
using System.Globalization;
using System.Management.Automation.Language;
using Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic;
using Microsoft.PowerShell.CrossCompatibility.Query;
using Microsoft.PowerShell.CrossCompatibility.Utility;
using System;
using System.IO;
using System.Runtime.Serialization;

namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.BuiltinRules
{
    public class UseCompatibleCmdlets2 : IScriptRule
    {
        private const string SETTING_TARGET_PATHS = "targetProfilePaths";

        private const string SETTING_ANY_UNION_PATHS = "anyProfilePath";

        private CompatibilityProfileLoader _profileLoader;

        public UseCompatibleCmdlets2()
        {
            _profileLoader = new CompatibilityProfileLoader();
        }

        public IEnumerable<DiagnosticRecord> AnalyzeScript(Ast ast, string fileName)
        {
            string cwd = Directory.GetCurrentDirectory();
            CmdletCompatibilityVisitor compatibilityVisitor = CreateVisitorFromConfiguration(fileName);
            ast.Visit(compatibilityVisitor);
            return compatibilityVisitor.GetDiagnosticRecords();
        }

        public string GetCommonName()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.UseCompatibleCmdletsDescription);
        }

        public string GetDescription()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.UseCompatibleCmdletsDescription);
        }

        public string GetName()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.UseCompatibleCmdletsName);
        }

        public RuleSeverity GetSeverity()
        {
            return RuleSeverity.Warning;
        }

        public string GetSourceName()
        {
            return string.Format(CultureInfo.CurrentCulture, Strings.SourceName);
        }

        public SourceType GetSourceType()
        {
            return SourceType.Builtin;
        }

        public DiagnosticSeverity DiagnosticSeverity => DiagnosticSeverity.Warning;

        private CmdletCompatibilityVisitor CreateVisitorFromConfiguration(string analyzedFileName)
        {
            IDictionary<string, object> ruleArgs = Helper.Instance.GetRuleArguments(GetName());
            var configPaths = ruleArgs[SETTING_TARGET_PATHS] as string[];
            var anyProfilePath = ruleArgs[SETTING_ANY_UNION_PATHS] as string;

            var targetProfiles = new List<CompatibilityProfileData>();
            foreach (string configPath in configPaths)
            {
                targetProfiles.Add(_profileLoader.GetProfileFromFilePath(configPath));
            }

            CompatibilityProfileData anyProfile = _profileLoader.GetProfileFromFilePath(anyProfilePath);
            return new CmdletCompatibilityVisitor(analyzedFileName, targetProfiles, anyProfile, rule: this);
        }

        private class CmdletCompatibilityVisitor : AstVisitor
        {
            private readonly IList<CompatibilityProfileData> _compatibilityTargets;

            private readonly CompatibilityProfileData _anyProfileCompatibilityList;

            private readonly List<DiagnosticRecord> _diagnosticAccumulator;

            private readonly string _analyzedFileName;

            private readonly UseCompatibleCmdlets2 _rule;

            public CmdletCompatibilityVisitor(
                string analyzedFileName,
                IList<CompatibilityProfileData> compatibilityTarget,
                CompatibilityProfileData anyProfileCompatibilityList,
                UseCompatibleCmdlets2 rule)
            {
                _analyzedFileName = analyzedFileName;
                _compatibilityTargets = compatibilityTarget;
                _anyProfileCompatibilityList = anyProfileCompatibilityList;
                _diagnosticAccumulator = new List<DiagnosticRecord>();
                _rule = rule;
            }

            public override AstVisitAction VisitCommand(CommandAst commandAst)
            {
                if (commandAst == null)
                {
                    return AstVisitAction.SkipChildren;
                }

                string commandName = commandAst.GetCommandName();
                if (commandName == null)
                {
                    return AstVisitAction.SkipChildren;
                }

                // Note:
                // The "right" way to eliminate user-defined commands would be to build
                // a list of:
                //  - all functions defined above this point
                //  - all modules imported
                // However, looking for imported modules could prove very expensive
                // and we would still miss things like assignments to the function: provider.
                // Instead, we look to see if a command of the given name is present in any
                // known profile, which is something of a hack.

                // This is not present in any known profiles, so assume it is user defined
                if (!_anyProfileCompatibilityList.Runtime.Commands.ContainsKey(commandName))
                {
                    return AstVisitAction.Continue;
                }

                // Check each target platform
                foreach (CompatibilityProfileData targetProfile in _compatibilityTargets)
                {
                    // If the target has this command, everything is good
                    if (targetProfile.Runtime.Commands.ContainsKey(commandName))
                    {
                        continue;
                    }

                    Version targetVersion = targetProfile.Platform.PowerShell.Version;
                    string platform = targetProfile.Platform.OperatingSystem.Name;
                    string message = $"The command '{commandName}' is not compatible with PowerShell v{targetVersion} on platform {platform}";

                    var diagnostic = new DiagnosticRecord(
                        message,
                        commandAst.Extent,
                        _rule.GetName(),
                        _rule.DiagnosticSeverity,
                        _analyzedFileName,
                        ruleId: null,
                        suggestedCorrections: null);

                    _diagnosticAccumulator.Add(diagnostic);
                }

                return AstVisitAction.Continue;
            }

            public IEnumerable<DiagnosticRecord> GetDiagnosticRecords()
            {
                return _diagnosticAccumulator;
            }
        }
    }
}