//
// Copyright (c) Microsoft Corporation.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//



using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Management.Automation.Language;
using System.Security;

namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
{
    /// <summary>
    /// Represents a result from a PSScriptAnalyzer rule.
    /// It contains a message, extent, rule name, and severity.
    /// </summary>
    public class DiagnosticRecord
    {
        private string message;
        private IScriptExtent extent;
        private string ruleName;
        private DiagnosticSeverity severity;
        private string scriptPath;
        private string ruleSuppressionId;
        private List<CorrectionExtent> suggestedCorrections;
        private bool canBeFixedAutomatically;

        /// <summary>
        /// Represents a string from the rule about why this diagnostic was created.
        /// </summary>
        public string Message
        {
            get { return message; }
            protected set { message = string.IsNullOrEmpty(value) ? string.Empty : value; }
        }

        /// <summary>
        /// Represents a span of text in a script.
        /// </summary>
        public IScriptExtent Extent
        {
            get { return extent; }
            protected set { extent = value; }
        }

        /// <summary>
        /// Represents the name of a script analyzer rule.
        /// </summary>
        public string RuleName
        {
            get { return ruleName; }
            protected set { ruleName = string.IsNullOrEmpty(value) ? string.Empty : value; }
        }

        /// <summary>
        /// Represents a severity level of an issue.
        /// </summary>
        public DiagnosticSeverity Severity
        {
            get { return severity; }
            set { severity = value; }
        }

        /// <summary>
        /// Represents the name of the script file that is under analysis
        /// </summary>
        public string ScriptName
        {
            get { return string.IsNullOrEmpty(scriptPath) ? string.Empty : System.IO.Path.GetFileName(scriptPath); }
        }

        /// <summary>
        /// Returns the path of the script.
        /// </summary>
        public string ScriptPath
        {
            get { return scriptPath; }
            protected set { scriptPath = string.IsNullOrEmpty(value) ? string.Empty : value; }
        }

        /// <summary>
        /// Returns the rule id for this record
        /// </summary>
        public string RuleSuppressionID
        {
            get { return ruleSuppressionId; }
            set { ruleSuppressionId = value; }
        }

        /// <summary>
        /// Returns suggested correction
        /// return value can be null
        /// </summary>
        public IEnumerable<CorrectionExtent> SuggestedCorrections
        {
            get { return suggestedCorrections;  }            
        }

        /// <summary>
        /// Returns whether it can be corrected automatically using the <see cref="AutoFix"/> method or by using the '-Fix' switch of Invoke-Scriptanalyzer
        /// </summary>
        public bool CanBeFixedAutomatically
        {
            get { return canBeFixedAutomatically; }
        }

        /// <summary>
        /// DiagnosticRecord: The constructor for DiagnosticRecord class.
        /// </summary>
        public DiagnosticRecord()
        {

        }
        
        /// <summary>
        /// DiagnosticRecord: The constructor for DiagnosticRecord class that takes in suggestedCorrection
        /// </summary>
        /// <param name="message">A string about why this diagnostic was created</param>
        /// <param name="extent">The place in the script this diagnostic refers to</param>
        /// <param name="ruleName">The name of the rule that created this diagnostic</param>
        /// <param name="severity">The severity of this diagnostic</param>
        /// <param name="scriptPath">The full path of the script file being analyzed</param>
        /// <param name="suggestedCorrections">The correction suggested by the rule to replace the extent text</param>
        /// <param name="canBeFixedAutomatically">Enough information is present in this object for an automatic if a scriptPath is present</param>
        public DiagnosticRecord(string message, IScriptExtent extent, string ruleName, DiagnosticSeverity severity, string scriptPath, string ruleId = null, List<CorrectionExtent> suggestedCorrections = null, bool canBeFixedAutomatically = false)
        {
            Message = message;
            RuleName = ruleName;
            Extent = extent;
            Severity = severity;
            ScriptPath = scriptPath;
            RuleSuppressionID = ruleId;
            this.suggestedCorrections = suggestedCorrections;
            this.canBeFixedAutomatically = canBeFixedAutomatically;
        }

        /// <summary>
        /// Uses the first element in the list SuggestedCorrections for the fix and replaces it with the Extentent.Text property
        /// Only supported for files at the moment.
        /// </summary>
        internal void AutoFix()
        {
            if (!string.IsNullOrEmpty(this.scriptPath))
            {
                var textToBeReplaced = this.Extent.Text;
                string textReplacement = this.SuggestedCorrections.FirstOrDefault().Text;

                // Fix rule
                var scriptPath = this.ScriptPath;
                string[] originalLines = new string[] { };
                try
                {
                    originalLines = File.ReadAllLines(scriptPath);
                }
                catch (Exception e)  // because the file was already read before, we do not expect errors and therefore it is not worth catching specifically
                {
                    Console.WriteLine($"Error reading file {scriptPath}. Exception: {e.Message}");
                }
                var lineNumber = this.SuggestedCorrections.FirstOrDefault().StartLineNumber;
                originalLines[lineNumber - 1] = originalLines[lineNumber - 1].Remove(this.Extent.StartColumnNumber - 1, textToBeReplaced.Length);
                originalLines[lineNumber - 1] = originalLines[lineNumber - 1].Insert(this.Extent.StartColumnNumber - 1, textReplacement);

                var errorMessagePreFix = "Failed to apply AutoFix when writing to file " + scriptPath + Environment.NewLine;
                // we need to catch all exceptions that could be thrown except for ArgumentException and ArgumentNullException because at this stage the file path has already been verified.
                try
                {
                    Console.WriteLine($"AutoFix {this.RuleName} by replacing '{textToBeReplaced}' with '{textReplacement}' in line {lineNumber} of file {scriptPath}");
                    File.WriteAllLines(scriptPath, originalLines);
                }
                catch (PathTooLongException)
                {
                    Console.WriteLine(errorMessagePreFix + "The specified path, file name, or both exceed the system - defined maximum length. " +
                                      "For example, on Windows - based platforms, paths must be less than 248 characters, and file names must be less than 260 characters.");
                }
                catch (DirectoryNotFoundException)
                {
                    Console.WriteLine(errorMessagePreFix + "The specified path is invalid (for example, it is on an unmapped drive).");
                }
                catch (IOException)
                {
                    Console.WriteLine(errorMessagePreFix + "An I/O error occurred while opening the file.");
                }
                catch (UnauthorizedAccessException)
                {
                    Console.WriteLine(errorMessagePreFix + "Path specified a file that is read-only or this operation is not supported on the current platform or the caller does not have the required permission.");
                }
                catch (SecurityException)
                {
                    Console.WriteLine(errorMessagePreFix + "You do not have the required permission to write to the file.");
                }
                catch (Exception e)
                {
                    Console.WriteLine(errorMessagePreFix + "Unexpected error:" + e.Message);
                }
            }
            else
            {
                Console.WriteLine("AutoFix functionality currently only supported for files");
            }
        }
    }

    /// <summary>
    /// Represents a severity level of an issue.
    /// </summary>
    public enum DiagnosticSeverity : uint
    {
        /// <summary>
        /// Information: This diagnostic is trivial, but may be useful.
        /// </summary>
        Information   = 0,

        /// <summary>
        /// WARNING: This diagnostic may cause a problem or does not follow PowerShell's recommended guidelines.
        /// </summary>
        Warning  = 1,

        /// <summary>
        /// ERROR: This diagnostic is likely to cause a problem or does not follow PowerShell's required guidelines.
        /// </summary>
        Error    = 2,
    };
}
