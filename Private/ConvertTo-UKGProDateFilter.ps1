function ConvertTo-UKGProDateFilter {
    <#
    .SYNOPSIS
        Builds a UKG Pro operator-prefixed date filter value.

    .DESCRIPTION
        UKG Pro date-time query parameters use an unusual inline-operator syntax
        where the comparison operator is part of the *value*, not a separate
        parameter. From the API docs:

            less than      =<MM-DD-YYYY      e.g. dateOfTermination=<01-01-1900
            greater than   =>MM-DD-YYYY      e.g. dateOfTermination=>01-01-1900
            equal to       =MM-DD-YYYY       e.g. dateOfTermination=01-01-1900
            between        ={MM-DD-YYYY,MM-DD-YYYY}

        Note the operator sits *after* the '=' that the query string already has,
        so the value we emit is the part after '='. For "greater than" the value
        is ">01-01-1900" (which yields ...?dateOfTermination=>01-01-1900).

        This helper takes friendly inputs and returns the correctly formatted
        value string, so callers never have to hand-assemble the operator syntax.

    .PARAMETER Operator
        One of: LessThan, GreaterThan, EqualTo, Between.

    .PARAMETER Date
        The date to compare against (for LessThan / GreaterThan / EqualTo).

    .PARAMETER RangeStart
        Start of the range (for Between).

    .PARAMETER RangeEnd
        End of the range (for Between).

    .EXAMPLE
        ConvertTo-UKGProDateFilter -Operator GreaterThan -Date '2026-01-01'
        # returns '>01-01-2026'  -> dateOfTermination=>01-01-2026

    .EXAMPLE
        ConvertTo-UKGProDateFilter -Operator Between -RangeStart '2026-01-01' -RangeEnd '2026-03-31'
        # returns '{01-01-2026,03-31-2026}'

    .NOTES
        Internal helper. Not exported.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Single')]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('LessThan', 'GreaterThan', 'EqualTo', 'Between')]
        [string]$Operator,

        [Parameter(Mandatory, ParameterSetName = 'Single')]
        [datetime]$Date,

        [Parameter(Mandatory, ParameterSetName = 'Range')]
        [datetime]$RangeStart,

        [Parameter(Mandatory, ParameterSetName = 'Range')]
        [datetime]$RangeEnd
    )

    # UKG Pro expects MM-DD-YYYY.
    $fmt = 'MM-dd-yyyy'

    switch ($Operator) {
        'LessThan'    { return '<' + $Date.ToString($fmt) }
        'GreaterThan' { return '>' + $Date.ToString($fmt) }
        'EqualTo'     { return $Date.ToString($fmt) }
        'Between'     {
            if ($PSCmdlet.ParameterSetName -ne 'Range') {
                throw "The Between operator requires -RangeStart and -RangeEnd."
            }
            return '{' + $RangeStart.ToString($fmt) + ',' + $RangeEnd.ToString($fmt) + '}'
        }
    }
}
