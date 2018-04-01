// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

using System.IO;
using System.Reflection;

namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
{
    internal static class PathResolver
    {
        /// <summary>
        /// A shim around the GetResolvedProviderPathFromPSPath method from PSCmdlet to resolve relative path including wildcard support.
        /// </summary>
        /// <typeparam name="string"></typeparam>
        /// <typeparam name="ProviderInfo"></typeparam>
        /// <typeparam name="GetResolvedProviderPathFromPSPathDelegate"></typeparam>
        /// <param name="input"></param>
        /// <param name="output"></param>
        /// <returns></returns>
        internal delegate GetResolvedProviderPathFromPSPathDelegate GetResolvedProviderPathFromPSPath<in @string, ProviderInfo, out GetResolvedProviderPathFromPSPathDelegate>(@string input, out ProviderInfo output);

        /// <summary>
        /// Retrieves the specified folder name from the Module directory structure.
        /// </summary>
        internal static string GetFolderInShippedModuleDirectory(string folderName)
        {
            // Find the compatibility files in Settings folder
            var path = typeof(Helper).GetTypeInfo().Assembly.Location;
            if (string.IsNullOrWhiteSpace(path))
            {
                return null;
            }

            var settingsPath = Path.Combine(Path.GetDirectoryName(path), folderName);
            if (!Directory.Exists(settingsPath))
            {
                // try one level down as the PSScriptAnalyzer module structure is not consistent
                // CORECLR binaries are in PSScriptAnalyzer/coreclr/, PowerShell v3 binaries are in PSScriptAnalyzer/PSv3/
                // and PowerShell v5 binaries are in PSScriptAnalyzer/
                settingsPath = Path.Combine(Path.GetDirectoryName(Path.GetDirectoryName(path)), folderName);
                if (!Directory.Exists(settingsPath))
                {
                    return null;
                }
            }

            return settingsPath;
        }
    }
}
