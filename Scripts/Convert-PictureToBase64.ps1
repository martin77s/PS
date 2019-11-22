function Convert-PictureToBase64 {
    param (
        [Parameter(Mandatory=$true)] [String] $Path
    )

    # try to guess the format by the file's extension
    $ext = $Path -replace '.*\.(\w+)$', '$1'
    if($ext -eq 'jpg') { $ext = 'jpeg' }
    $format = [System.Drawing.Imaging.ImageFormat]::$ext

    # Convert the image to base64
    $stream = New-Object -TypeName System.IO.MemoryStream
    $image = [System.Drawing.Image]::FromFile($Path)
    $image.Save($stream, $format)
    $bytes = [Byte[]]($stream.ToArray())
    [System.Convert]::ToBase64String($bytes, 'InsertLineBreaks')
}
 
# convert a random picture 
$pic = dir $env:windir\Web\Wallpaper *.jpg -rec | select -first 1
$base64 = Convert-PictureToBase64 -Path $pic.FullName
$base64
