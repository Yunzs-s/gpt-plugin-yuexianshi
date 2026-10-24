param([string]$WidgetSource)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$app=Split-Path $PSScriptRoot -Parent
if(!$WidgetSource){$WidgetSource=Join-Path $app 'widget.ps1'}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($WidgetSource,[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Widget source did not parse'}
foreach($name in @('Limit-WidgetHorizontalPosition','Limit-WidgetVerticalPosition','Get-WidgetLayoutScale','Set-WidgetIndependentLayout')){
  $definition=$ast.Find({param($node)$node-is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name-eq $name},$true)
  . ([ScriptBlock]::Create($definition.Extent.Text))
}
function Sync-WidgetCharacterColors {}
$checks=0
foreach($dpi in @(1.0,1.25,1.5,2.0)){
  foreach($sizes in @(@{character=1.0;bubble=1.0},@{character=0.6;bubble=2.5},@{character=2.5;bubble=0.6})){
    foreach($side in @('left','right')){
      $script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $app 'widget.xaml'),[Text.Encoding]::UTF8))
      try{
        $script:ui=@{};foreach($name in @('Root','Girl','Bubble','Tail','TailNear','MenuButton','FacingScale')){$script:ui[$name]=$script:window.FindName($name)}
        $script:scale=$sizes.character;$script:bubbleScale=$sizes.bubble;$script:displayScale=Get-WidgetLayoutScale
        Set-WidgetIndependentLayout
        $script:ui.FacingScale.ScaleX=if($side-eq 'left'){-1}else{1}
        $null=([Windows.Interop.WindowInteropHelper]::new($script:window)).EnsureHandle()
        if($script:window.IsVisible -or [Windows.PresentationSource]::FromVisual($script:ui.Root.Parent)){throw 'Fixture must remain disconnected before its first Show'}
        $frame=[pscustomobject]@{Left=-1920;Top=0;Right=1920;Bottom=2160}
        $factor=$script:displayScale*$dpi
        $girlLeft=[Windows.Controls.Canvas]::GetLeft($script:ui.Girl)
        if($side-eq 'left'){$girlLeft=350-$girlLeft-$script:ui.Girl.Width}
        foreach($requested in @(-99999,0,99999)){
          $x=Limit-WidgetHorizontalPosition $frame $dpi $requested
          $y=Limit-WidgetVerticalPosition $frame $dpi $requested
          $left=$x+(14+$girlLeft)*$factor
          $top=$y+(14+[Windows.Controls.Canvas]::GetTop($script:ui.Girl))*$factor
          if($left-lt $frame.Left-1 -or $left+$script:ui.Girl.Width*$factor-gt $frame.Right+1){throw 'Cold placement escaped horizontal bounds'}
          if($top-lt $frame.Top-1 -or $top+$script:ui.Girl.Height*$factor-gt $frame.Bottom+1){throw 'Cold placement escaped vertical bounds'}
          $checks++
        }
      }finally{$script:window.Close()}
    }
  }
}
Write-Output ('PASS: '+$checks+' cold desktop placements before first Show, both facings, independent scales and 4 DPI settings')
