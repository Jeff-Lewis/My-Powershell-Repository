function Write-CRUD
{
    <#
    .Synopsis
        Writes CRUD commands for a table in Azure
    .Description
        Writes PowerShell commands to create a CRUD system around a table and partition in Azure
        
        
        CRUD stands for Create, Read, Update, and Delete
        
        
        Write-Crud creates the following commands.
        
        * Add-$Noun (aliased to New-$Noun and Create-$Noun)
        * Get-$Noun (aliased to Search-$Noun and Read-$Noun)
        * Update-$noun (aliased to Set-$Noun)
        * Remove-$Noun (aliased to Remove-$Noun)   
    
        
        Write-Crud can create tables with an arbitrary schema.
        
        
        It can also use a well-known schemas, found at either [http://schema.org](http://schema.org) or [http://shouldbeonschema.org](http://shouldbeonschema.org)
        
    .Example
        Write-CRUD -Table My -Partition CustomItem -TypeName MyCustomCrud -Field @{
            'Name' = 'The Name of the Item'
            'Description' = 'The description of the item'            
        } 
    .Example
        Write-Crud -Table My -Partition Blog -Schema http://schema.org/BlogPosting 
    .Link
        Add-AzureTable
    .Link
        Get-AzureTable
    .Link
        Search-AzureTable
    .Link
        Set-AzureTable
    .Link
        Update-AzureTable
    .Link
        Remove-AzureTable
    .Link
        Using_Azure_Table_Storage_In_Pipeworks
    .Link
        Writing_Crud_In_Pipeworks
    .Link
        http://schema.org
    .Link
        http://shouldbeonschema.org    
    #>
    [CmdletBinding(DefaultParameterSetName='Schema')]
    [OutputType([string])]
    param(
    # The name of the table
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [string]$Table,
    
    # The name of the partition
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [string]$Partition,
    
    # The storage account setting    
    [string]$StorageAccountSetting = 'AzureStorageAccountName',
    # The storage key setting
    [string]$StorageKeySetting = 'AzureStorageAccountKey',

    # The SQL Connection String Setting
    [string]$ConnectionStringSetting = 'SqlAzureConnectionString',
    
    # Any arbitrary fields to put into a custom CRUD system.
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='CustomField',Position=3)]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='Schema')]
    [Hashtable]$Field,
    
    # The typename of the data in the field
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='CustomField',Position=4)]
    [string]$TypeName,
    
    # The Schema.org schema used for the table
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='Schema',Position=2)]
    [string]$Schema,
    
    # If set, will require certain fields
    
    [string[]]$RequiredField,
    
    # The parition where read codes would be found
    
    [string]$ReadCodePartition,
    
    # If set, the Read command in the CRUD system will automatically sort results
    [string]$SortField,
    
    # If set, the Read command in the CRUD system will automatically sort results as a type
    [Parameter(Position=6)]
    [ValidateSet('String','DateTime','Float','Int')]
    [string]$SortType,
    
    # The field on the object that references the read code object
    [string]$ReadCodeCrossReferenceField,
    
    # If set, will make these fields request multiple lines for input
    [string[]]$LargeField = 'description',

    # If set, will make these fields editable HTML
    [string[]]$HtmlField = @('description', 'articlebody'),
    
    # If set, will only include a few fields from the schema
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='Schema')]
    [string[]]$IncludeField,
   
    
    # The noun to use for the generated command.  If this is not set, the commands will have a noun named $Table$Partition
    [string]$Noun,
    
    # If set, the CRUD system will be designed to work with users, and be able to query for my items or items of a user ID
    [Switch]$IsUserSystem,
    
    # The partition to look in for user names and ids
    [string]$UserPartition,
    
    # The type of key used by the crud system
    [Parameter(Position=5)]
    [ValidateSet('Guid', 'Hex', 'SmallHex', 'Sequential', 'Named', 'Parameter')]   
    [string]$KeyType  = 'Hex',
        
    # The order of the fields    
    [string[]]$FieldOrder,
    
    # If set, will not convert markdown found in the table
    [Switch]$DoNotConvertMarkdown,
    
    # If set, will not connect to storage
    [Switch]$DoNotConnect,

    # If set, will force uniquely named items
    [Switch]$UniquelyNamed,
    
    # A description to use for the commands
    [string]$Description       
    )
    
    process {
        $fieldParameterBlock = ""        
        # Create (Add-$Name, alias New-$Name, Create-$Name, Put-$Name)        
        
                
        if ($psCmdlet.ParameterSetName -eq 'CustomField') {
                
            # If custom fields are provided, use them to set up the CRUD schema
            $schemaFields = 
                $Field.GetEnumerator() |
                    ForEach-Object {
                        New-Object PSOBject -Property @{
                            Name = $_.key
                            Description = $_.Value
                        }
                    }
                    
        } elseif ($psCmdlet.ParameterSetName -eq 'Schema') {
        
            # If not, grab the schema from the site
            $schemaHtml = $schema | 
                Get-Web -HideProgress -Url {$_ }
                
            # First, try parsing out the properties as microdata
            $schemaFields = 
                Get-Web -Html $schemaHtml -ItemType http://shouldbeonschema.org/Property
                
            
            # Add an ID to schemas from schema.org, if not present
            $hasId = $false
            
            
            if (-not $schemaFields) {            
                # Schema.org requires hand parsing of the HTML
                $schemaFields = Get-Web -Html $schemaHtml -Tag tr  | 
                    # Luckily, they use clean CSS.  Don't ever change, schema.org (seriously, it will break me)
                    Where-Object {$_.Tag -like "*prop-nam*" }  | 
                    # Now pick out the key pieces of information from the schema: the name and the description
                    ForEach-Object {
                        # The name is in a code element
                        $name = $_.xml.th.code
                        # A string description would be the innerText of the last column in the table row
                        $description = @($_.xml.td)[-1].innerText                     
                        if ($name -eq 'Id') {
                            $hasId= $true
                        }
                        
                        if ($includeField -and $includeField -contains $name) {
                            New-Object PSOBject -Property @{
                                Name = $name
                                Description = $description
                            }
                        } else {
                            New-Object PSOBject -Property @{
                                Name = $name
                                Description = $description
                            }
                        }
                        
                    }  -End {
                        
                        if (-not $hasId) {
                            New-Object PSObject -Property @{
                                Name= 'Id'
                                Description = "An Identifier for the Object"
                            }
                        }
                    }
            }
            
            if ($field) {
                $schemaFields += $Field.GetEnumerator() |
                        ForEach-Object {
                            New-Object PSOBject -Property @{
                                Name = $_.key
                                Description = $_.Value
                            }
                        }
            }
        }  
        
        
        
        # If this came from schema.org, use that typename.  Otherwise, use the typename provided
        $objTypeNAme = $(if ($psCmdlet.parameterSetName -eq 'schema') {$schema }else {$typeName })
        $p =1
        if (-not $RequiredField) {
            $RequiredField = 'Name'
        }
        
        # If there was a field order, use this to pick out the schema fields
        if ($fieldOrder) {
            $nameTable = $schemaFields | Where-Object { $_.Name } | Group-Object Name -AsHashTable
            $schemaFields = foreach ($f in $fieldOrder) {
                $nameTable.$f
            }
        }
                    
        foreach ($sc in @($schemaFields)) {
            if (-not $sc) { continue }
            
            # Add a mandatory attribute for required fields
            $mandatoryAttribute =
                if ($RequiredField -contains $sc.Name) {
                    'Mandatory=$true, '
                } else {
                    ''
                }
            
            # Force name to be position 0, if found
            if ($sc.Name -eq 'Name') {
                $oldP = $p
                $p =0                    
            }


            $InputLines = 1
            
            $ParameterTypeAttribute = '[string]'
            if ($sc.PropertyType -eq 'Boolean') {
                $ParameterTypeAttribute = '[switch]'
            } elseif ($sc.PropertyType -eq 'Integer') {
                $ParameterTypeAttribute = '[int]'
            } elseif ($sc.PropertyType -eq 'Float') {
                $ParameterTypeAttribute = '[Double]'
            } elseif ($sc.PropertyType -like "*date*") {
                $ParameterTypeAttribute = '[DateTime]'
            } elseif ($sc.Name -like "Date*") {
                $ParameterTypeAttribute = '[DateTime]'
            }
            if (-not $sc.Name) { continue }
            $capitalizedName = $sc.Name[0].ToString().ToUpper() + $sc.Name.Substring(1)
            $fieldParameterBlock+= "
    <#     
    $($sc.Description)
    $(if ($largeField -contains $sc.Name) { '|LinesForInput 10' })             
    $(if ($htmlField -contains $sc.Name) { '|ContentEditable' })             
    #>
    [Parameter(${mandatoryAttribute}Position=$p, ValueFromPipelineByPropertyName=`$true)]
    $ParameterTypeAttribute
    " +'$' + $capitalizedName + ","
            # We really want name to be first
            if ($p -eq 0) {
                $p = $oldP
            }
            $p++
        }              
            
        # The CRUD system will keep items compressed, and, unless told otherwise, will automatically convert items kept in Markdown within the CRUD system into HTML    
        $unpackParameterBlock = "`$DoNotConvertMarkdown = $(if ($DoNotConvertMarkdown) { '$true'} else {'$false'});
        " + {            
            $item = $_
            $item.psobject.properties |                         
                Where-Object { 
                    $_.Value -and
                    ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                    (-not $_.Value.ToString().Contains(' ')) 
                }|                        
                ForEach-Object {
                    try {
                        $expanded = Expand-Data -CompressedData $_.Value
                        if ($expanded) {
                            $item | Add-Member NoteProperty $_.Name $expanded -Force
                        }                        
                    } catch{
                        Write-Verbose $_
                    
                    }
                }
                
            if (-not $DoNotConvertMarkdown) {                 
                $item.psobject.properties |                         
                    Where-Object { 
                        $_.Value -and
                        ('Timestamp', 'RowKey', 'TableName', 'PartitionKey' -notcontains $_.Name) -and
                        (-not $_.Value.ToString().Contains('<')) 
                    }|                                   
                    ForEach-Object {
                        try {
                            $fromMarkdown = ConvertFrom-Markdown -Markdown $_.Value
                            $item | Add-Member NoteProperty $_.Name $fromMarkdown -Force
                        } catch{
                            Write-Verbose $_
                        
                        }
                    }
            }
            $item     
            
        }
       
        #$fieldParameterBlock 
        $beginBlock = "
    begin {
        `$storageAccount = if ((Get-WebConfigurationSetting -Setting '$StorageAccountSetting')) {
            (Get-WebConfigurationSetting -Setting '$StorageAccountSetting')
        } elseif ((Get-SecureSetting -Name '$StorageAccountSetting' -ValueOnly)) {
            (Get-SecureSetting -Name '$StorageAccountSetting' -ValueOnly)
        }

        `$storageKey = if ((Get-WebConfigurationSetting -Setting '$StorageKeySetting')) {
            (Get-WebConfigurationSetting -Setting '$StorageKeySetting')
        } elseif ((Get-SecureSetting -Name '$StorageKeySetting' -ValueOnly)) {
            (Get-SecureSetting -Name '$StorageKeySetting' -ValueOnly)
        }
        "
            
        $joinWith = "`",$([Environment]::NewLine + ' ' * 12)`""
        if (-not $TypeName) {
            $schemaName = ([uri]$schema).Segments[-1]            
            $TypeName = $schemaName
        }
        if ($IsUserSystem) {
            $attachUserIdChunk = {
                $UserID = if ($session -and $session['User'].UserId) {
                    $session['User'].UserId
                } elseif ($Request -and $Request['AppKey']) {
                    $userFound = 
                        Search-AzureTable -StorageAccount $storageAccount -StorageKey $storageKey -TableName $Table -Filter "PartitionKey eq '$UserPartition' and SecondaryApiKey eq '$($Request['AppKey'])'"
                    if (-not $userFound) { 
                        return
                    } else {
                        $userFound.UserId
                    }
                    
                } else {
                    $env:UserName
                }
                if ($UserID) {
                    $ToInput | Add-Member NoteProperty UserID $UserID -Force 
                }
            }
        }
        
        $findChunk = if ($UniquelyNamed) {
            [ScriptBlock]::Create("
            Search-AzureTable -TableName '$Table' -Filter `"Name eq '`$(`$toInput.Name)'`"|
            Where-Object {
                `$_.PartitionKey -eq '$Partition'
            }
            ")
        } else {
            {$false}
        }
        
        $processBlock = "
    process {
        foreach (`$v in 'ErrorAction', 'ErrorVariable', 'WarningAction', 'WarningVariable', 'OutVariable', 'OutBuffer') {
            `$null = `$psBoundParameters.Remove(`$v)
        }
        `$UserPartition = $(if ($UserPartition) { '$Userpartition' } else { '$partition'})
        `$toInput = New-Object PSObject -Property `$psBoundParameters
        $(if ($IsUserSystem) { $attachUserIdChunk })
        `$toInput.psTypenames.clear()
        `$toInput.psTypenames.add('$(if ($psboundparameters.schema) {$schema }else {$typeName })')
        `$bigItems = `$psBoundParameters.GetEnumerator() |
            Where-Object { 
                `$_.Value.Length -gt 2kb
            } |
            ForEach-Object {
                `$toInput | Add-Member NoteProperty `$_.Key (Compress-Data -String `$_.Value) -Force -PassThru
            }
        
        `$found = & { $findChunk} 
            
        if (-not `$found) {
            `$table = '$table'
            `$partition = '$partition'
            `$rowKey = . { $(
                if ($KeyType -eq 'GUID') {
                    {[GUID]::NewGuid()}
                } elseif ($KeyType -eq 'Hex') {
                    {"{0:x}" -f (Get-Random)}
                } elseif ($KeyType -eq 'SmallHex') {
                    {"{0:x}" -f ([int](Get-Random -Maximum 512kb))}
                } elseif ($KeyType -eq 'Sequential') {
                    {
                        
                $foundTheEnd = $false
                $toFind = 1 
                $lastToFind = 0
                while (-not $FoundTheEnd) {
                    $r = Search-AzureTable -TableName $table -Filter "PartitionKey eq '$partition' and RowKey eq '$ToFind'" -Select RowKey -ErrorAction SilentlyContinue
                    if (-not $r) { 
                        $foundTheEnd = $true 
                    } else {
                        $lastToFind = $toFind
                        $ToFind *= 2
                    }
                }
                
                $foundExactEnd = $false
                $start = $lastToFind
                $end = $ToFind
                $middle = $start + [int](($end - $start) / 2)
                while (-not $foundExactEnd) {
                    $r = Search-AzureTable -TableName $table -Filter "PartitionKey eq '$partition' and RowKey eq '$middle'" -Select RowKey -ErrorAction SilentlyContinue
                    
                    if ($r) {
                        # In the number space, new middle is between middle and end   
                        $start = $middle
                    } else {
                        # Out of the number space, new middle is between start and middle
                        $end = $middle                
                    }
                    $middle = $start + [int](($end - $start) / 2)
                    if ([Math]::Abs($start - $end) -le 1 ) {
                        $foundExactEnd = $true             
                    }
                }
                $end
                        
                        
                    }
                } elseif ($KeyType -eq 'Named') {
                    {$name}
                }
            ) }
            `$toInput | 
                Set-AzureTable -TableName '$table' -PartitionKey '$Partition' -RowKey `$rowKey -PassThru
        }
    }            
            "            
        $beginBlock += ('$schemaFields += "' + (($schemaFields | Where-object { $_.Name } | Select-Object -ExpandProperty Name)-join $joinWith) + '"')
        $beginBlock += '
    }
'

        if (-not $Noun) {
            $Noun = "${Table}${Partition}"
        }

        $adddescription = 
            if ($Description) {
                "Adds $description"
            } else {
                "Adds ${Noun}s"
            }



        #region Create the Commands
$out = "function Add-$Noun {
    <#
    .Synopsis
        Adds items to $Table $Partition
    .Description
        $adddescription 
    .Example
        Add-$Noun
    .Link
        Set-AzureTable
    #>
    param(
    $($fieldParameterBlock.TrimEnd(','))
    )
    $beginBlock
    $processBlock
    $endBlock
    
}

Set-Alias New-$Noun Add-$Noun
Set-Alias Create-$Noun Add-$Noun

try { 
    Export-ModuleMember -Function Add-$Noun -Alias New-$Noun,Create-$Noun -ErrorAction SilentlyContinue
} catch {
    Write-Debug 'Not in a module'
}
"         
        
        $SortString = if ($SortField) {
            if ($SortType) {
                "Sort-Object { [$SortType]`$_.$SortField } "
            } else {
                "Sort-Object {`$_.$SortField }"
            }
        } else {
            ""
        }
        
        $getdescription = 
            if ($Description) {
                "Gets $description"
            } else {
                "Gets ${Noun}s"
            }

        
        # Read (Get-$Name, alias Read-$Name, Search-$Name, Find-$Name)
$out += @"
function Get-$Noun {
    <#
    .Synopsis
        Gets $Typename items from $table $partition
    .Description
        $getdescription
    .Example
        Get-$noun
    .Example
        Get-$noun 'search term'
    .Example
        Get-$noun -ExactName 'exact name'
    .Example
        Get-$noun -ExactName 'exact name'
    .Link
        Get-AzureTable
    .Link
        Search-AzureTable
    .Link
        Write-Crud
    #>
    $(if ($IsUserSystem) { "[CmdletBinding(DefaultParameterSetName='RowKey')]" } else { "[CmdletBinding(DefaultParameterSetName='All')]" })
    param(
    # The keyword to find within the items
    [Parameter(Mandatory=`$true,Position=0,ParameterSetName='Keyword')]
    $(if ($IsUserSystem) { "[Parameter(Position=0,ParameterSetName='MyItem')]" })
    [string]
    `$Keyword,

    # The properties to return back from each item
    [Parameter(ValueFromPipelineByPropertyName=`$true,Position=1)]    
    [string[]]
    `$Select,
    
    # Find an item with this exact name
    [Parameter(Mandatory=`$true,ParameterSetName='ExactName')]
    $(if ($IsUserSystem) { "[Parameter(Position=1,ParameterSetName='MyItem')]" })
    [string]
    `$ExactName,
    
    # Find an item in this exact row
    [Parameter(Mandatory=`$true,ParameterSetName='RowKey',ValueFromPipelineByPropertyName=`$true)]
    [string]
    `$RowKey,
    
    [Parameter(Mandatory=`$true,ParameterSetName='All',ValueFromPipelineByPropertyName=`$true)]
    [switch]
    `$All,
    
    $(if ($IsUserSystem) {
    "
    # If set, returns only items owned by the current user id
    [Parameter(Mandatory=`$true,ParameterSetName='MyItem')]
    [Switch]`$My${Noun},
    "
    })
    
    $(if ($IsUserSystem) {
    "
    # If set, returns only items owned by a user id
    [Parameter(Mandatory=`$true,ParameterSetName='ByUserID',ValueFromPipelineByPropertyName=`$true)]
    [string]`$UserID,
    "
    })
    
    $(if ($ReadCodePartition -and $ReadCodeCrossReferenceField) {
    "
    # If set, returns only items with the matching readcode
    [Parameter(Mandatory=`$true,ParameterSetName='ByReadCode',ValueFromPipelineByPropertyName=`$true)]
    [string]`$ReadCode,
    "
    })
    
    # If set, will exclude table information
    [switch]    
    `$ExcludeTableInfo    
    )
    
    begin {
        `$unpackIt = {
            $unpackParameterBlock
        }
        `$storageAccount = if ((Get-WebConfigurationSetting -Setting '$StorageAccountSetting')) {
            (Get-WebConfigurationSetting -Setting '$StorageAccountSetting')
        } elseif ((Get-SecureSetting -Name '$StorageAccountSetting' -ValueOnly)) {
            (Get-SecureSetting -Name '$StorageAccountSetting' -ValueOnly)
        }

        `$storageKey = if ((Get-WebConfigurationSetting -Setting '$StorageKeySetting')) {
            (Get-WebConfigurationSetting -Setting '$StorageKeySetting')
        } elseif ((Get-SecureSetting -Name '$StorageKeySetting' -ValueOnly)) {
            (Get-SecureSetting -Name '$StorageKeySetting' -ValueOnly)
        }
        
    }
    
    process {
        `$selectIt = @{
            ExcludeTableInfo=`$ExcludeTableInfo
            StorageAccount = `$storageAccount
            StorageKey=  `$storageKey
        }
        if (`$select) {
            `$selectIt['Select'] = `$select
        }
        if (`$psCmdlet.ParameterSetName -eq 'All') {
            
            Search-AzureTable -TableName '$table' -Where { `$_.PartitionKey -eq '$Partition' } @selectIt |
            $SortString 
            ForEach-Object `$unpackIt
        } elseif (`$psCmdlet.ParameterSetName -eq 'Keyword') {
            if (`$keyword.Trim() -eq '*') {
                throw "Keyword `$keyword is too broad"
                return
            }

            if (-not `$select) {
                `$select = 'Name', 'Description', 'RowKey', 'PartitionKey'
            } else {
                `$select += 'RowKey', 'PartitionKey'
                `$select = `$select | Select-Object -Unique
            }
            Search-AzureTable -TableName '$table' -Where { `$_.PartitionKey -eq '$Partition' } -Select `$select| 
                Where-Object {
                    `$_.Name -ilike "*`$keyword*" -or
                    `$_.Description -ilike "*`$keyword*"
                } |
                Get-AzureTable -TableName '$table' |
                $SortString 
                ForEach-Object `$unpackIt
        } elseif (`$psCmdlet.ParameterSetName -eq 'ExactName') {
            Search-AzureTable -TableName '$table' -Filter "PartitionKey eq '$Partition' and Name eq '`$ExactName'" @selectIt|
            $SortString 
            ForEach-Object `$unpackIt
        } elseif (`$psCmdlet.ParameterSetName -eq 'RowKey') {
            Search-AzureTable -TableName '$table' -Filter "PartitionKey eq '$Partition' and RowKey eq '`$RowKey'" @selectIt |
            $SortString 
            ForEach-Object `$unpackIt
        } elseif (`$psCmdlet.ParameterSetName -eq 'ByUserID')  {            
            Search-AzureTable -TableName '$table' -Filter "PartitionKey eq '$Partition' and UserID eq '`$UserID'" @selectIt |
            $SortString 
            ForEach-Object `$unpackIt            
        }  elseif (`$psCmdlet.ParameterSetName -eq 'ReadCode')  {            
            `$readCodeFound = Search-AzureTable -TableName '$table' -Filter "PartitionKey eq '$ReadCodePartition' and ReadCode eq '`$ReadCode'"
            `$allReadings = foreach (`$rcF in `$readCodeFound) {
                if (-not `$rcf) {continue }
                Search-AzureTable -TableName '$table' -Filter "PartitionKey eq '$Partition' and $ReadCodeCrossReferenceField eq '`$(`$rcf.RowKey)'"
            }
            `$allReadings |                
                $SortString 
                ForEach-Object `$unpackIt            
        } elseif (`$psCmdlet.ParameterSetName -eq 'MyItem')  {
            if (`$session -and `$session['User'].UserID) {
                if (-not `$keyword) { `$keyword = '*' } 
                if (`$exactName) { `$keyword = `$exactName } 

                Search-AzureTable -TableName '$table' -Filter "PartitionKey eq '$Partition' and UserID eq '`$(`$session['User'].UserID)'" @selectIt |
                $SortString 
                ForEach-Object `$unpackIt |
                Where-Object {
                    `$_.Name -ilike "*`$keyword*" -or
                    `$_.Description -ilike "*`$keyword*"
                }
            } elseif (`$env:UserName) {
                Search-AzureTable -TableName '$table' -Filter "PartitionKey eq '$Partition' and UserID eq '`$(`$env:UserName)'" @selectIt |
                $SortString 
                ForEach-Object `$unpackIt
            }                        
        }
    }
}

Set-Alias Read-$Noun Get-$Noun
Set-Alias Search-$Noun Get-$Noun

try { 
    Export-ModuleMember -Function Get-$Noun -Alias Read-$Noun,Search-$Noun -ErrorAction SilentlyContinue
} catch {
    Write-Debug 'Not in a module'
}

"@
        
        
        # Update (Update-$Name, alias Set-$Name)
        $processBlock = "
    process {
        `$toInput = New-Object PSObject -Property `$psBoundParameters
        $(if ($IsUserSystem) { $attachUserIdChunk })
        `$toInput.psTypenames.clear()
        `$toInput.psTypenames.add('$objTypeNAme')
        `$psBoundParameters.GetEnumerator() |
            Where-Object { 
                `$_.Value.Length -gt 2kb
            } |
            ForEach-Object {
                `$toInput | Add-Member NoteProperty `$_.Key (Compress-Data -String `$_.Value) -Force 
            }
                    
        `$found = Search-AzureTable -TableName '$Table' -Filter `"PartitionKey eq '$Partition' and RowKey eq '`$RowKey'`" |
            Where-Object {
                `$_.PartitionKey -eq '$Partition'
            }
            
        if (`$found) {
            if (`$found.UserId -and (`$toInput.UserId -ne `$found.UserId)) {
                Write-Error 'Item does not belong to you'
                return            
            }
            `$row = `$found.rowKey
            `$null = `$toInput.psObject.Properties.Remove('Merge')
            `$null = `$toInput.psObject.Properties.Remove('RowKey')
            
            `$toInput | 
                Update-AzureTable -TableName '$table' -PartitionKey '$partition' -RowKey `$rowKey -Value { `$_ } -Merge:`$merge -PassThru
        }
    }            
            "           
    $updatedescription = 
            if ($Description) {
                "Updates $description"
            } else {
                "Updates ${Noun}s"
            }

$out+= "function Update-$Noun {
    <#
    .Synopsis
        Updates items in $Table $Partition
    .Description
        $updatedescription  
    .Example
        Get-$noun -ExactName 'A Specific Item' | 
            Update-$Noun -Description 'A New Description'
    .Link
        Update-AzureTable
    #>
    param(    
    [Parameter(Mandatory=`$true,ParameterSetName='RowKey',ValueFromPipelineByPropertyName=`$true)]
    [string]
    `$RowKey,
    
    [switch]
    `$Merge,
    
    $($fieldParameterBlock.TrimEnd(','))
    )
    $beginBlock
    $processBlock
    $endBlock
    
}

Set-Alias Set-$Noun Update-$Noun

try { 
    Export-ModuleMember -Function Update-$Noun -Alias Set-$Noun -ErrorAction SilentlyContinue
} catch {
    Write-Debug 'Not in a module'
}
"                
        # Delete (Remove-$Name, alias Delete-$Name)        
        $removedescription = 
            if ($Description) {
                "Updates $description"
            } else {
                "Updates ${Noun}s"
            }



$out += @"
function Remove-$Noun 
{    
    <#
    .Synopsis
        Removes items from $Table $Partition
    .Description
        $removedescription
    .Example
        Get-$noun -ExactName 'A Specific Item' | 
            Remove-$Noun 
    .Link
        Remove-AzureTable
    #>        
    [CmdletBinding(DefaultParameterSetName='RowKey',SupportsShouldProcess=`$true,ConfirmImpact='High')]
    param(
    [Parameter(Mandatory=`$true,Position=0,ParameterSetName='Keyword')]
    [string]
    `$Keyword,
    
    [Parameter(Mandatory=`$true,ParameterSetName='ExactName')]
    [string]
    `$ExactName,
    
    [Parameter(Mandatory=`$true,ParameterSetName='RowKey',ValueFromPipelineByPropertyName=`$true)]
    [string]
    `$RowKey        
    )
    
    process {                        
        `$getParams = @{} + `$psBoundParameters
        `$getParams.Remove('WhatIf')
        `$getParams.Remove('Confirm')
        if (-not `$psBoundParameters.confirm -or (`$psBoundParameters.Confirm -eq `$false)) {
            if (-not `$psBoundParameters.whatIf) {
                `$confirmImpact = 'None'
            }
        }
        Get-$Noun @getParams |
            Where-Object {
                `$item = `$_
                `$toInput = New-Object PSObject
                $(if ($IsUserSystem) { 
                    $attachUserIdChunk                     
                })
                
                if (-not `$item.UserId) { return `$true } 
                if (`$item.UserId -eq `$toInput.UserId) {
                    return `$true
                }                
            } | 
            Remove-AzureTable 
    }
}

Set-Alias Delete-$Noun Remove-$Noun

try { 
    Export-ModuleMember -Function Remove-$Noun -Alias Delete-$Noun -ErrorAction SilentlyContinue
} catch {
    Write-Debug 'Not in a module'
}

$(if (-not $($DoNotConnect)) {
"
`$storageAccount = if ((Get-WebConfigurationSetting -Setting '$StorageAccountSetting')) {
    (Get-WebConfigurationSetting -Setting '$StorageAccountSetting')
} elseif ((Get-SecureSetting -Name '$StorageAccountSetting' -ValueOnly)) {
    (Get-SecureSetting -Name '$StorageAccountSetting' -ValueOnly)
}

`$storageKey = if ((Get-WebConfigurationSetting -Setting '$StorageKeySetting')) {
    (Get-WebConfigurationSetting -Setting '$StorageKeySetting')
} elseif ((Get-SecureSetting -Name '$StorageKeySetting' -ValueOnly)) {
    (Get-SecureSetting -Name '$StorageKeySetting' -ValueOnly)
}


# Connect to Azure Table Storage
`$null = Get-AzureTable -TableName '$table' -StorageAccount `$storageAccount -StorageKey `$storageKey
"
})
"@

        $out
        #endregion Create the Commands
       
        
        
    }
}
 

# SIG # Begin signature block
# MIINGAYJKoZIhvcNAQcCoIINCTCCDQUCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU9LJcLUX4rKZDoraXZ9QOXd+F
# pO2gggpaMIIFIjCCBAqgAwIBAgIQAupQIxjzGlMFoE+9rHncOTANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE0MDcxNzAwMDAwMFoXDTE1MDcy
# MjEyMDAwMFowaTELMAkGA1UEBhMCQ0ExCzAJBgNVBAgTAk9OMREwDwYDVQQHEwhI
# YW1pbHRvbjEcMBoGA1UEChMTRGF2aWQgV2F5bmUgSm9obnNvbjEcMBoGA1UEAxMT
# RGF2aWQgV2F5bmUgSm9obnNvbjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBAM3+T+61MoGxUHnoK0b2GgO17e0sW8ugwAH966Z1JIzQvXFa707SZvTJgmra
# ZsCn9fU+i9KhC0nUpA4hAv/b1MCeqGq1O0f3ffiwsxhTG3Z4J8mEl5eSdcRgeb+1
# jaKI3oHkbX+zxqOLSaRSQPn3XygMAfrcD/QI4vsx8o2lTUsPJEy2c0z57e1VzWlq
# KHqo18lVxDq/YF+fKCAJL57zjXSBPPmb/sNj8VgoxXS6EUAC5c3tb+CJfNP2U9vV
# oy5YeUP9bNwq2aXkW0+xZIipbJonZwN+bIsbgCC5eb2aqapBgJrgds8cw8WKiZvy
# Zx2qT7hy9HT+LUOI0l0K0w31dF8CAwEAAaOCAbswggG3MB8GA1UdIwQYMBaAFFrE
# uXsqCqOl6nEDwGD5LfZldQ5YMB0GA1UdDgQWBBTnMIKoGnZIswBx8nuJckJGsFDU
# lDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAw
# bjA1oDOgMYYvaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1j
# cy1nMS5jcmwwNaAzoDGGL2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFz
# c3VyZWQtY3MtZzEuY3JsMEIGA1UdIAQ7MDkwNwYJYIZIAYb9bAMBMCowKAYIKwYB
# BQUHAgEWHGh0dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwgYQGCCsGAQUFBwEB
# BHgwdjAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsG
# AQUFBzAChkJodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEy
# QXNzdXJlZElEQ29kZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG
# 9w0BAQsFAAOCAQEAVlkBmOEKRw2O66aloy9tNoQNIWz3AduGBfnf9gvyRFvSuKm0
# Zq3A6lRej8FPxC5Kbwswxtl2L/pjyrlYzUs+XuYe9Ua9YMIdhbyjUol4Z46jhOrO
# TDl18txaoNpGE9JXo8SLZHibwz97H3+paRm16aygM5R3uQ0xSQ1NFqDJ53YRvOqT
# 60/tF9E8zNx4hOH1lw1CDPu0K3nL2PusLUVzCpwNunQzGoZfVtlnV2x4EgXyZ9G1
# x4odcYZwKpkWPKA4bWAG+Img5+dgGEOqoUHh4jm2IKijm1jz7BRcJUMAwa2Qcbc2
# ttQbSj/7xZXL470VG3WjLWNWkRaRQAkzOajhpTCCBTAwggQYoAMCAQICEAQJGBtf
# 1btmdVNDtW+VUAgwDQYJKoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNV
# BAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIG
# A1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAw
# MFoXDTI4MTAyMjEyMDAwMFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lD
# ZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGln
# aUNlcnQgU0hBMiBBc3N1cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZI
# hvcNAQEBBQADggEPADCCAQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1
# f+Wondsy13Hqdp0FLreP+pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+ykn
# x9N7I5TkkSOWkHeC+aGEI2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4c
# SocI3wz14k1gGL6qxLKucDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTm
# K/5sy350OTYNkO/ktU6kqepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/B
# ougsUfdzvL2FsWKDc0GCB+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0w
# ggHJMBIGA1UdEwEB/wQIMAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMDMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8E
# ejB4MDqgOKA2hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3JsMDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9
# bAACBDAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BT
# MAoGCGCGSAGG/WwDMB0GA1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNV
# HSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEA
# PuwNWiSz8yLRFcgsfCUpdqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH2
# 0ZJ1D1G0bqWOWuJeJIFOEKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV
# +7qvtVHCjSSuJMbHJyqhKSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyP
# u6j4xRJon89Ay0BEpRPw5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD
# 2rOwjNXpDd32ASDOmTFjPQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6S
# kepobEQysmah5xikmmRR7zGCAigwggIkAgEBMIGGMHIxCzAJBgNVBAYTAlVTMRUw
# EwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20x
# MTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25pbmcg
# Q0ECEALqUCMY8xpTBaBPvax53DkwCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwx
# CjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGC
# NwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFHntNZos5y7a1WUg
# 2UUrbrJu7KI+MA0GCSqGSIb3DQEBAQUABIIBAHDcCoKt0EDoZPCd/16d9ZWBLpf8
# CWj5I591jr1QTGHt5TfG3O+areEbLNrh5bOLxL0lbE00a2/ao1UWkjaXqUqkCvTa
# HieIi4kASsrGEVNwcP6kiC3dn8b5vqUCZljXeQwrv8g5K/8aCVL7w2xalWT+2PhB
# BlhcxLEs2i3TODu5HBSaY+udapJDmxnGb36yXbbpRj5w0JPXxiGMSfnts+UwG4VA
# Ig8BxRBXv+v5LiUqfIVvJP3Sj2SOb9zOVbpzcVxnFsNsqShCEIOOgFR8AlOyUpI9
# bZYcKvy4uZPYDKaLPvyscsNwC+QCgEgsrmNp9mNwYCTi+QvkoTAYaMXLqqo=
# SIG # End signature block
