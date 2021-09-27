clear
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wh="https://www.eve-scout.com/api/wormholes"
$req1 = Invoke-Webrequest -URI $wh -UseBasicParsing
$WHJSON= $req1 | ConvertFrom-Json
#$homesys="Oimmo"
$homesys=$env:EVE_HOME
#$hookUrlDiscord = "https://discord.com/api/webhooks/823696475321925673/c_CA7w6C5ghfqyj2MbqnRKZ2SoAWS6tPFN9khoN2MapS-PHPVjKVcFkgax_qNMzecLDM"
$hookUrlDiscord=$env:Discord_URL
$routeFromHome=@()
$WHJSONToCheck = "/home/therabot/wh.json"
$contentOldFile="/home/therabot/contentOld.json"

#Fetch Thera destinations
$destinations=(($WHJSON).destinationSolarSystem | Where-Object {$_.name -notmatch "Thera" } | Where-Object {$_.name -notmatch "J"}).name

function getPathFrom {
param (
        $WHJSON,
        $destinations,
        $source
    )
    $route=@()
    foreach ($destination in $destinations) {            
                $actualDistance=New-Object -TypeName psobject
                $dest=$destination
                # Test if its a system with space in the name
                if ($dest.Contains(" ")) {
                    $dest=($dest.split(" ")[0])+"_"+($dest.split(" ")[1])
                    $myURI = "https://evemaps.dotlan.net/route/"+$source+":"+$dest
                }
                $myURI = "https://evemaps.dotlan.net/route/"+$source+":"+$dest
                $req = Invoke-Webrequest -URI $myURI -UseBasicParsing
                $html = ConvertFrom-Html -Content $req
                $p = $html.SelectNodes("//*[contains(@class, 'tablelist table-tooltip')]")
                $jump=($p.ChildNodes | Where-Object {$_.name -eq "tr"}).count - 2
                $actualDistance | Add-Member -MemberType NoteProperty -Name System -Value $dest
                $actualDistance | Add-Member -MemberType NoteProperty -Name Jump -Value $jump
                $route +=$actualDistance
            

        }
return $route
}

#Generate Report
function GenerateTheraReport {
param (
        $WHJSON,
        $path
    )      
        #Security Status close to Hubs      
        $closeAmarrSS=[math]::Round(($whjson | where-object {$_.destinationSolarSystem.name -eq $path.closeAmarrSystem} | select destinationSolarSystem).destinationSolarsystem.security,1)
        $closeJitaSS=[math]::Round(($whjson | where-object {$_.destinationSolarSystem.name -eq $path.closeJitaSystem} | select destinationSolarSystem).destinationSolarsystem.security,1)
        $homeToThera="Thera close to Home "+$homesys+ " : "+$path.closeTheraHomeSystem+" ("+$path.closeTheraJump+" Jumps)`n"
        $theraToJita= "Thera close to Jita : "+$path.closeJitaSystem+" ("+$path.closeJitaJump+" Jumps) Security Status "+$closeJitaSS+"`n"
        $theraToAmarr= "Thera close to Amarr : "+$path.closeAmarrSystem+" ("+$path.closeAmarrJump+" Jumps) Security Status "+$closeAmarrSS+"`n"
        $separator=" ------------------------------------------------------`n"
        $TotalJumpJita= "Total Jump from Home "+$homesys+" to Jita : "+($path.closeTheraJump+$path.closeJitaJump)+"`n"
        $TotalJumpAmarr= "Total Jump from Home "+$homesys+" to Amarr : "+($path.closeTheraJump+$path.closeAmarrJump)+"`n"
        $content =  $homeToThera+$theraToJita+$theraToAmarr+$i7sToThera+$separator+$TotalJumpJita+$TotalJumpAmarr+$TotalJumpI7S
        $payload = [PSCustomObject]@{
            content = $content
        }
        $path | ConvertTo-Json | Out-File $contentOldFile
        $WHJSON | ConvertTo-Json | Out-File $WHJSONToCheck
        Invoke-RestMethod -Uri $hookUrlDiscord -Method Post -Body ($payload | ConvertTo-Json) -ContentType 'Application/Json'

}

function getAllPath {

    $AllPath=New-Object -TypeName psobject
    $PathToAmarr= getPathFrom -source "Amarr" -WHJSON $WHJSON -destinations $destinations
    $PathToJita = getPathFrom -source "Jita" -WHJSON $WHJSON -destinations $destinations
    $PathToHome = getPathFrom -source ($homesys) -WHJSON $WHJSON -destinations $destinations
    $AllPath | Add-Member -MemberType NoteProperty -Name closeAmarrSystem -Value ((($PathToAmarr | Sort-Object -Property Jump)[0]).System)
    $AllPath | Add-Member -MemberType NoteProperty -Name closeAmarrJump -Value ((($PathToAmarr | Sort-Object -Property Jump)[0]).Jump)
    $AllPath | Add-Member -MemberType NoteProperty -Name closeJitaSystem -Value ((($PathToJita | Sort-Object -Property Jump)[0]).System)
    $AllPath | Add-Member -MemberType NoteProperty -Name closeJitaJump -Value ((($PathToJita | Sort-Object -Property Jump)[0]).Jump)
    $AllPath | Add-Member -MemberType NoteProperty -Name closeTheraHomeSystem -Value ((( $PathToHome | Sort-Object -Property Jump)[0]).System)
    $AllPath | Add-Member -MemberType NoteProperty -Name closeTheraJump -Value ((( $PathToHome | Sort-Object -Property Jump)[0]).Jump)
    $AllPath | Add-Member -MemberType NoteProperty -Name closeTheraI7SSystem -Value ((($PathToI7S | Sort-Object -Property Jump)[0]).System)

return $AllPath
}

#region main
#Read old EveScout Thera WH JSON
$oldJSON = ((get-content $WHJSONToCheck -ErrorAction SilentlyContinue) | ConvertFrom-Json)
$oldContent=((get-content $contentOldFile -ErrorAction SilentlyContinue) | ConvertFrom-Json)

#Testing if Thera WH JSON is different of the new one and launch a discovery if so
if (Test-Path $WHJSONToCheck -PathType leaf)
{
    if ((Compare-Object -ReferenceObject $WHJSON -DifferenceObject $oldJSON -Property id).count -eq 0) {
        Write-Host "Thera WH Not changed ...."
        break
    }
    else {
#Get AllPath
    $path=getAllPath
    $WHJSON | ConvertTo-Json | Out-File $WHJSONToCheck
#Compare if there is new path
    if (Test-Path $contentOldFile -PathType leaf) {
        if (@(Compare-Object $oldContent $path -Property closeAmarrSystem,closeAmarrJump,closeJitaSystem,closeJitaJump,closeTheraHomeSystem,closeTheraJump,closeTheraI7SSystem,closeTheraI7SJump | Where-Object { $_.SideIndicator -eq '=>' }).Count -eq 0) {
            write-host "No destination change skipping Discord..."
            $WHJSON | ConvertTo-Json | Out-File $WHJSONToCheck
            break
        }
        else {
            GenerateTheraReport -WHJSON $WHJSON -path $path
        }
        
        } 
    else {
            GenerateTheraReport -WHJSON $WHJSON -path $path
    }

    }
} 
else {
    $path=getAllPath

#Compare if there is new path
    if (Test-Path $contentOldFile -PathType leaf) {
        if (@(Compare-Object $oldContent $path -Property closeAmarrSystem,closeAmarrJump,closeJitaSystem,closeJitaJump,closeTheraHomeSystem,closeTheraJump,closeTheraI7SSystem,closeTheraI7SJump | Where-Object { $_.SideIndicator -eq '=>' }).Count -eq 0) {
            write-host "No destination change skipping Discord..."
            $WHJSON | ConvertTo-Json | Out-File $WHJSONToCheck
            break
        }
        else {
            GenerateTheraReport -WHJSON $WHJSON -path $path
            $WHJSON | ConvertTo-Json | Out-File $WHJSONToCheck
        }
    }
GenerateTheraReport -WHJSON $WHJSON -path $path
$WHJSON | ConvertTo-Json | Out-File $WHJSONToCheck
}
#endregion
