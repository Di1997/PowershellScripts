#region Init
[console]::TreatControlCAsInput = $true

Set-Alias -Name new -Value New-Object

#region Class
Class Wrapper {
	static [System.Collections.ArrayList] $inner = @()
	static [System.Collections.ArrayList] $outer = @()

	[ScriptBlock] $function
	[String] $name
	[String] $description
	[Boolean] $isInterface = $false
	[Boolean] $isInner = $true
	
	Wrapper($data, [Boolean] $isInner) {
		$this.name = $data.name
		$this.description = $data.description
		$this.function = $data.function
		$this.isInterface = $data.isInterface
		$this.isInner = $isInner
	}
	
	static Create([String]$name, [String]$description, [ScriptBlock] $function) {
		[Wrapper]::inner.Add((New-Object Wrapper(@{name = $name; description = $description; function = $function}, $true))) | Out-Null
	}
	
	static OuterCreate($data) {
		[Wrapper]::outer.Add((New-Object Wrapper($data, $false))) | Out-Null
	}
	
	static [System.Collections.ArrayList] GetFunctions() {
		return (@([Wrapper]::inner, [Wrapper]::outer)|%{$_})
	}
}

Class Page {
	[System.Collections.IEnumerable] $array
	[int] $index
	[int] $size
	
	Page([System.Collections.IEnumerable] $array, $size) {
		$this.index = 0
		$this.size = $size
		$this.array = $array
	}
	
	[System.Collections.IEnumerable] Get() {
		$beginning = $this.index * $this.size
		$end = (($this.index+1)*$this.size)-1
		
		return $this.array[$beginning..$end]
	}
	
	[int] GetCurrentPage() {
		return $this.index
	}
	
	[int] GetMaxPage() {
		return [math]::Floor($this.array.Count / $this.size)
	}
	
	[Boolean] Next() {
		if($this.GetMaxPage() -eq $this.index) {
			return $false
		}
		
		$this.index++
		return $true
	}
	
	[Boolean] Previous() {
		if($this.index -eq 0) {
			return $false
		}
		
		$this.index--
		return $true
	}
}

#region Attributes
Class Name : Attribute {
	Name($in) {}
}

Class Description : Attribute {
	Description($in) {}
}
#endregion
#endregion

#region Enums
Enum InputOutcomes {
	BadInput
	Empty
}

Enum MenuOutcomes {
	Abort
	Done
	Error
}
#endregion

#region Functions
function Validate($value, $type) {
	$out = @{value=$null; error=$null}
	try{
		if([string]::IsNullOrEmpty($value)) {
			$out.error = [InputOutcomes]::Empty
		} else {
			$out.value = switch ($type) {
				'Int32' { [Int32] $value }
				default { $value }
			}
		}
		
		return $out
	} catch {
		$out.error = [InputOutcomes]::BadInput
		return $out
	}
}

function Menu($function) {
	cls
	
	if($function.isInterface) {
		return InterfaceMenu($function)
	}
	
	$params = $function.function.Ast.ParamBlock.Parameters
	$paramIn = @()
	$stop = $false
	
	Write-Host("=====================================================")
	Write-Host("Name: $($function.name)")
	Write-Host("Description: $($function.description)")
	
	if($params.Length -gt 0) {
		Write-Host("")
		Write-Host("Press Enter without typing anything to exit")
	}
	
	Write-Host("=====================================================")
	Write-Host("")
	
	foreach($parameter in $params) {
		$message = ParseParam($parameter)
		
		while($true) {
			$in = Read-Host($message)
			
			$value = Validate -value $in -type $parameter.StaticType.Name
			
			if($value.error -eq [InputOutcomes]::Empty) {
				$stop = $true
				break
			}
			
			if($value.error -eq [InputOutcomes]::BadInput) {
				Write-Host "Invalid input. Try again"
			}
			
			if($value.error -eq $null) {
				$paramIn += $value.value
				break
			}
		}
		
		if($stop) {
			return [MenuOutcomes]::Abort
			break
		}
	}
	
	if(-not $stop) {
		try {
			Write-Host("")
			Write-Host("=====================================================")
			$result = Invoke-Command $function.function -ArgumentList $paramIn
			Write-Host("")
			Write-Host("Results:")
			Write-Host("")
			Write-Host($result) -Separator "`n"
			Write-Host("")
			Write-Host("=====================================================")
		} catch {
			Write-Host("")
			Write-Host("=====================================================")
			Write-Host("Error while processing:")
			Write-Host("")
			Write-Host("")
			Write-Host("$($_.Exception)")
			Write-Host("")
			Write-Host("=====================================================")
			return [MenuOutcomes]::Error
		}
	}
	
	return [MenuOutcomes]::Done
}

function InterfaceMenu($function) {

	$params = $function.function.Ast.ParamBlock.Parameters
	$paramIn = @()
	$stop = $false
	
	if($params.Length -gt 0) {
		Write-Host("=====================================================")
		Write-Host("Name: $($function.name)")
		Write-Host("Description: $($function.description)")
		Write-Host("")
		Write-Host("Press Enter without typing anything to exit")
		Write-Host("=====================================================")
		Write-Host("")
		
		foreach($parameter in $params) {
			$message = ParseParam($parameter)
			
			while($true) {
				$in = Read-Host($message)
				
				$value = Validate -value $in -type $type
				
				if($value.error -eq [InputOutcomes]::Empty) {
					$stop = $true
					break
				}
				
				if($value.error -ne [InputOutcomes]::BadInput) {
					$paramIn += $value.value
					break
				}
			}
			
			if($stop) {
				return [MenuOutcomes]::Abort
				break
			}
		}
	}
	
	if(-not $stop) {
		try {
			$result = Invoke-Command $function.function -ArgumentList $paramIn
		} catch {
			Write-Host("")
			Write-Host("=====================================================")
			Write-Host("Exception while running script:")
			Write-Host("")
			Write-Host("")
			Write-Host("$($_.Exception)")
			Write-Host("")
			Write-Host("=====================================================")
			return [MenuOutcomes]::Error
		}
	}
	
	return [MenuOutcomes]::Done
}

function Out($in) {
Write-Host($in) -Separator "`n"
}

function ParseParam($param) {
	$parsed_attributes = @{}
	$message = ""
	$capitalizer = (Get-Culture).TextInfo
	
	$name = $param.Name.VariablePath.UserPath
	$type = $param.StaticType.Name
	
	$attributes = $param.Attributes
	
	foreach($attribute in $attributes) {
		if($attribute.PositionalArguments -ne $null) {
			$parsed_attributes[$attribute.TypeName.Name] = $attribute.PositionalArguments[0].Value
		}
	}
	
	$out = @{Description = $parsed_attributes["Description"]; Name = $parsed_attributes["Name"]}
	
	if($out.Description -ne $null -or $out.Name -ne $null) {
		if([String]::IsNullOrEmpty($out.Description)) {
			$message = "$($out.Name)"
		} elseif ([String]::IsNullOrEmpty($out.Name)) {
			$message = "[$type] $($capitalizer.ToTitleCase($name)) ($($out.Description))"
		} else {
			$message = "$($out.Name) ($($out.Description))"
		}
	} else {
		$message = "[$type] $($capitalizer.ToTitleCase($name))"
	}
	
	return $message
}
#endregion

$keys = '1234567890qwertyuiopasdfghjklzxcvbnm'.ToCharArray()
$specKeys = ',.'.ToCharArray()

#region Reading outer scripts and converting to functions
if(Test-Path "Scripts") {
	cd Scripts
	$files = dir -File -Name
	
	$errors = @()
	
	foreach($file in $files) {
		if($file -eq "Example.ps1" -or $file.StartsWith("--")) {
			continue
		}
		
		if(-not $file.EndsWith(".ps1")) {
			continue
		}
		
		$scriptFile = Get-Command ".\$file"
		
		$sb = $scriptFile.ScriptBlock
		$details = @{}
		$params = @("param(")
		
		if($sb -eq $null) {
			try {
				[scriptblock]::Create($scriptFile.ScriptContents)
				$errors += @{File = $file; Exception = "No exception found."}
			} catch {
				$errors += @{File = $file; Exception = $_}
			}
			
			continue
		}
		
		if($sb.Ast.EndBlock.Statements.Count -eq 0) {
			continue
		}
		
		$script = $sb.Ast.EndBlock.Statements|%{
		if($_.Name -ne "_GetParams") {
			$_.Extent.Text
		} else {
			$details = icm $_.Body.GetScriptBlock()
		}}
		
		if($sb.Ast.ParamBlock.Parameters.Count -gt 0 -and $details["VarDescriptions"] -ne $null -and $details["VarDescriptions"].Count -gt 0) {
			$sb.Ast.ParamBlock.Parameters|%{
				$name = $_.Name.VariablePath.ToString()
				$info = $details["VarDescriptions"][$name]
				
				if($info.Name -ne $null) {
					$params += "[Name(`"$($info.Name)`")]"
				}
				
				if($info.Description -ne $null) {
					$params += "[Description(`"$($info.Description)`")]"
				}
				
				$params += $_.Extent.Text
			}
		}
		
		$params += ")`n"
		
		$script = $params + $script
		
		$details.function = [scriptblock]::Create(($script -Join "`n"))
		
		if([String]::IsNullOrEmpty($details.Name)) {
			$details.Name = $file
		}
		if([String]::IsNullOrEmpty($details.Description)) {
			$details.Description = "No description provided"
		}
		
		[Wrapper]::OuterCreate($details)
	}
	
	if($errors.Length -gt 0) {
	
		Write-Host("Couldn't load next files!")
		Write-Host("")
		
		foreach($parse_error in $errors) {
			Write-Host("=====================================================")
			Write-Host "$($parse_error.File)`n`n$($parse_error.Exception)" -ForegroundColor Red -BackgroundColor Black
			Write-Host("=====================================================")
			Write-Host("")
		}
		
		pause
	}
}
#endregion
#endregion

#region Commands [Wrapper]::Create("NAME","DESCRIPTION",{CODE})
[Wrapper]::Create("Insert query","Generates SQL insert query from your clipboard into your clipboard",{
	$data = Get-Clipboard
	$headers = $data[0].Split("`t")|%{if($_ -ne ""){$_}}
	$rows = @()
	$dataRows = $data|Select-Object -Skip 1
	
	foreach($row in $dataRows) {
	
		$rowData = $row.Split("`t")
		$out = @()
		
		for($i = 0; $i -lt $rowData.length; $i++) {
		
			if($i -eq $headers.Length) {
				break;
			}
		
			$data = $rowData.Get($i)
			
			if($data -ne "NULL" -and ($data -as [int]) -eq $null -and $headers.Get($i) -notlike "*ID" -and $headers.Get($i) -ne "STAMP" -and $data -ne "GETDATE()"){
				$out += "N'$data'"
			}
			elseif($headers.Get($i) -eq "ID" -and $data -eq "") {
				#attempt to generate our own ID
				$guid = [Guid]::NewGuid().ToByteArray()
				$guid[15] = $guid[15] -band 0x3F
				$out += New-Object System.Numerics.BigInteger @(,$guid)
			}
			elseif($headers.Get($i) -eq "STAMP" -and $data -eq "") {
				$out += "GETDATE()"
			}
			else{
				if($data -ne ''){
					$out += $data
				}
			}
		}
		
		if($out.Length -eq $headers.Length) {
			$rows += "($($out -join ","))"
		}
	}

	$rows = $rows|Where-Object {$_ -ne '()'}

	$values = $rows -join ",`n`t`t"
	$insert = ($headers|%{"[$_]"}) -join "`n`t`t,"

	$into = Read-Host -Prompt "Input DB name"

	$query = "INSERT INTO [$into]`n`t`t($insert)`n`tVALUES`n`t`t$values"

	Set-Clipboard($query)
	
	return "Insert query generation finished"
})
[Wrapper]::Create("Generate IDs","Generate n IDs",{
	param(
	[Name("New IDs count")]
	[int] $newIds
	)
	$out = @()
	for($i = 0; $i -lt $newIds; $i++) {
		$guid = [Guid]::NewGuid().ToByteArray()
		$guid[15] = $guid[15] -band 0x3F
		$out += New-Object System.Numerics.BigInteger @(,$guid)
	}
	return $out
})
[Wrapper]::Create("Fix keyboard","Fix keyboard languages",{
	$list = Get-WinUserLanguageList
	$list.Add("en-US")
	Set-WinUserLanguageList $list -Force
	$list.Remove(($list | Where-Object LanguageTag -like 'en-US'))
	Set-WinUserLanguageList $list -Force
})
[Wrapper]::Create("Get devices","Obtains devices that can go sleep",{
	return Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi | Where {$_.Enable}
})
[Wrapper]::Create("Fix devices","Stops computer from turning off the decides that can sleep",{
	Write-Host "Obtaining devices...`n`n"
	$to_fix = @()
	$to_fix += Get-WmiObject MSPower_DeviceEnable -Namespace root\wmi | Where {$_.Enable}
	if($to_fix.Count -gt 0) {
	$devices = $to_fix|%{$_.InstanceName.Substring(0, $_.InstanceName.Length-2)}|%{@{device_info = Get-PnpDeviceProperty -InstanceId $_}}
	Write-Host "Devices to be fixed:"
	Write-Host "===================="
	Out(($devices|%{"$(($_.device_info|where KeyName -eq "DEVPKEY_Device_Class").Data) / $(($_.device_info|where KeyName -eq "DEVPKEY_NAME").Data)"}))
	Write-Host "====================`n`n"
	Write-Host "Fixing..."
	$to_fix|%{$_.Enable = $False;$_.psbase.Put()} > $Null
	Write-Host "Done!"
	}
	else {
	Write-Host "No sleeping devices found!`n" -ForegroundColor Red
	}
})
#endregion

#region Interface
$page = new Page([Wrapper]::GetFunctions(), $keys.Count)
while($true) {
	cls #Clearing first
	
	Write-Host("")
	
	$functions = $page.Get()

	if($functions.Count -ge 2) {
		$inner = $functions|%{if($_.isInner){$_}}
		$outer = $functions|%{if(-not $_.isInner){$_}}
		
		Write-Host("=====================================================`n")
			
		if($inner.Count -gt 0) {
			Write-Host("Inner functions:")
			foreach ($function in $inner) {
				Write-Host("[$($keys.Get($functions.IndexOf($function)).toString().toUpper())] $($function.name): $($function.description)")
			}
		}
		if($outer.Count -gt 0) {
			Write-Host("`nOuter functions:")
			foreach ($function in $outer) {
				Write-Host("[$($keys.Get($functions.IndexOf($function)).toString().toUpper())] $($function.name): $($function.description)")
			}
		}
		
		Write-Host("`n=====================================================`n`n")
		
		if($page.GetMaxPage() -gt 0) {
			Write-Host("Page: $($page.GetCurrentPage()+1) / $($page.GetMaxPage()+1)")
			Write-Host("[<] - Previous page; [>] - Next page`n")
		}

		Write-Host("Press a key to select function")
		
		while($true) {
			$keyPress = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").VirtualKeyCode
			
			$keyPress = [Char]::ToLower([Char]$keyPress)
			
			$index = $keys.IndexOf($keyPress)
			$specIndex = $specKeys.IndexOf($keyPress)
			
			if($index -ne -1 -and $index -lt $functions.Count) {
				$function = $functions[$index]
				
				$result = Menu($function)

				if($result -eq [MenuOutcomes]::Error){
					pause
					break
				} elseif ($result -eq [MenuOutcomes]::Done) {
					pause
					break
				} elseif ($result -eq [MenuOutcomes]::Abort) {
					break
				}
			} elseif ($specIndex -ne -1) {
				if($specIndex -eq 0) {
					if($page.Previous()) {
						break
					}
				} elseif ($specIndex -eq 1) {
					if($page.Next()) {
						break
					}
				}
			}
		}
		
	} elseif ($functions.Count -eq 1) {
		while($true) {
			Menu($functions[0]) | out-null
			pause
		}
		
	} else {
		Write-Host "No scripts detected!"
		pause
		Exit
	}
}
#AK: MTcwMzQ1OTgxMTIzMTAwNjgz.Xn4-kg.wiWwBEQL2sv_sRL7nSVwCtzOCJo
#endregion