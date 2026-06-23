param(
  [int]$Seconds = 900,
  [int]$IntervalMs = 500
)

$ErrorActionPreference = "Stop"

$source = @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class Win32Dialog {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  public delegate bool EnumChildProc(IntPtr hWnd, IntPtr lParam);

  [DllImport("user32.dll")]
  public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

  [DllImport("user32.dll")]
  public static extern bool EnumChildWindows(IntPtr hWndParent, EnumChildProc lpEnumFunc, IntPtr lParam);

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

  [DllImport("user32.dll")]
  public static extern bool IsWindowVisible(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);

  public const int BM_CLICK = 0x00F5;

  public static string Text(IntPtr hWnd) {
    var sb = new StringBuilder(512);
    GetWindowText(hWnd, sb, sb.Capacity);
    return sb.ToString();
  }

  public static string ClassName(IntPtr hWnd) {
    var sb = new StringBuilder(256);
    GetClassName(hWnd, sb, sb.Capacity);
    return sb.ToString();
  }
}
"@

if (-not ("Win32Dialog" -as [type])) {
  Add-Type -TypeDefinition $source
}

function Get-ChildWindows([IntPtr]$Parent) {
  $children = New-Object System.Collections.Generic.List[IntPtr]
  [Win32Dialog]::EnumChildWindows($Parent, {
    param([IntPtr]$hWnd, [IntPtr]$lParam)
    $script:childrenRef.Add($hWnd)
    return $true
  }, [IntPtr]::Zero) | Out-Null
  return $children
}

function Invoke-HwpAllowAllOnce {
  $clicked = $false
  $hwpKoreanTitle = ([string][char]0xD55C) + ([string][char]0xAE00)
  $promptPatterns = @(
    (([string][char]0xD30C)+([string][char]0xC77C)+([string][char]0xC744)+([string][char]0x0020)+([string][char]0xC0AC)+([string][char]0xC6A9)+([string][char]0xD558)+([string][char]0xC5EC)),
    (([string][char]0xC811)+([string][char]0xADFC)+([string][char]0xD558)+([string][char]0xB824)+([string][char]0xB294)+([string][char]0x0020)+([string][char]0xC2DC)+([string][char]0xB3C4)),
    (([string][char]0xD5C8)+([string][char]0xC6A9)+([string][char]0xD558)+([string][char]0xAC70)+([string][char]0xB098)),
    (([string][char]0xC720)+([string][char]0xCD9C)+([string][char]0xC758)+([string][char]0x0020)+([string][char]0xC704)+([string][char]0xD5D8)),
    (([string][char]0xC815)+([string][char]0xC0C1)+([string][char]0xC801)+([string][char]0xC778)+([string][char]0x0020)+([string][char]0xC791)+([string][char]0xC5C5))
  )
  $allowAllText = (([string][char]0xBAA8)+([string][char]0xB450)+([string][char]0x0020)+([string][char]0xD5C8)+([string][char]0xC6A9))
  $topWindows = New-Object System.Collections.Generic.List[IntPtr]
  $script:topWindowsRef = $topWindows
  [Win32Dialog]::EnumWindows({
    param([IntPtr]$hWnd, [IntPtr]$lParam)
    if ([Win32Dialog]::IsWindowVisible($hWnd)) {
      $script:topWindowsRef.Add($hWnd)
    }
    return $true
  }, [IntPtr]::Zero) | Out-Null

  foreach ($win in $topWindows) {
    $title = [Win32Dialog]::Text($win)
    if (($title -notlike "*$hwpKoreanTitle*") -and ($title -notlike "*Hwp*")) { continue }

    $children = New-Object System.Collections.Generic.List[IntPtr]
    $script:childrenRef = $children
    [Win32Dialog]::EnumChildWindows($win, {
      param([IntPtr]$hWnd, [IntPtr]$lParam)
      $script:childrenRef.Add($hWnd)
      return $true
    }, [IntPtr]::Zero) | Out-Null

    $allText = ($children | ForEach-Object { [Win32Dialog]::Text($_) }) -join "`n"
    $isFileAccessPrompt = $false
    foreach ($pattern in $promptPatterns) {
      if ($allText -like "*$pattern*") {
        $isFileAccessPrompt = $true
        break
      }
    }
    if (-not $isFileAccessPrompt) { continue }

    foreach ($child in $children) {
      $text = [Win32Dialog]::Text($child)
      $class = [Win32Dialog]::ClassName($child)
      if ($class -eq "Button" -and $text -like "*$allowAllText*") {
        [Win32Dialog]::SendMessage($child, [Win32Dialog]::BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null
        Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') clicked: $text"
        $clicked = $true
        break
      }
    }
  }
  return $clicked
}

$deadline = (Get-Date).AddSeconds($Seconds)
Write-Output "HWP allow-all watcher started for $Seconds seconds."
while ((Get-Date) -lt $deadline) {
  Invoke-HwpAllowAllOnce | Out-Null
  Start-Sleep -Milliseconds $IntervalMs
}
Write-Output "HWP allow-all watcher finished."
