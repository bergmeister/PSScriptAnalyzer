# bug (baz does not get indented) -> Pipelineindentation -> can we make 'temporary' indentation more permanent?

foo `
-bar |
baz


foo `
# comment
-bar |
baz


<# Test: in useConsitentindetion
        It "When a comment is in the middle of a multi-line statement with preceding line continuation and succeeding pipeline" {
            $scriptDefinition = @'
foo `
# comment
-bar |
baz
'@
            $expected = @'
foo `
    # comment
    -bar |
        baz
'@
            Invoke-FormatterAssertion $scriptDefinition $expected 3 $settings
        }

#>