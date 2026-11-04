Add-Type -AssemblyName System.Drawing

function Build-SmartFootwearIcon {
    param([int]$size = 1024)

    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $cx = $size / 2.0
    $cy = $size / 2.0

    # 1. Background: Sleek Dark Obsidian / Cyber Space gradient
    $bgRect = New-Object System.Drawing.RectangleF(0, 0, $size, $size)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $bgRect,
        [System.Drawing.Color]::FromArgb(255, 12, 17, 32),
        [System.Drawing.Color]::FromArgb(255, 4, 6, 12),
        45.0
    )
    $g.FillRectangle($bgBrush, $bgRect)
    $bgBrush.Dispose()

    # 2. Radial ambient energy core glow in background
    $glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $glowPath.AddEllipse([float]($cx - $size * 0.45), [float]($cy - $size * 0.45), [float]($size * 0.9), [float]($size * 0.9))
    $pbg = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath)
    $pbg.CenterColor = [System.Drawing.Color]::FromArgb(70, 0, 242, 254)
    $pbg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 4, 6, 12))
    $g.FillPath($pbg, $glowPath)
    $pbg.Dispose()
    $glowPath.Dispose()

    # Second ambient glow (electric magenta near heel/top)
    $glowPath2 = New-Object System.Drawing.Drawing2D.GraphicsPath
    $glowPath2.AddEllipse([float]($cx - $size * 0.25), [float]($cy - $size * 0.35), [float]($size * 0.6), [float]($size * 0.6))
    $pbg2 = New-Object System.Drawing.Drawing2D.PathGradientBrush($glowPath2)
    $pbg2.CenterColor = [System.Drawing.Color]::FromArgb(50, 247, 37, 133)
    $pbg2.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 4, 6, 12))
    $g.FillPath($pbg2, $glowPath2)
    $pbg2.Dispose()
    $glowPath2.Dispose()

    # 3. Outer Neon Hex / Stride Ring border
    $ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(40, 0, 242, 254), [float]($size * 0.004))
    $g.DrawEllipse($ringPen, [float]($size * 0.08), [float]($size * 0.08), [float]($size * 0.84), [float]($size * 0.84))
    $ringPen.Dispose()

    # Concentric stride radar arcs
    $arcPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(60, 114, 9, 183), [float]($size * 0.005))
    $arcPen.DashStyle = [System.Drawing.Drawing2D.DashStyle]::Dash
    $g.DrawArc($arcPen, [float]($size * 0.14), [float]($size * 0.14), [float]($size * 0.72), [float]($size * 0.72), -40.0, 120.0)
    $g.DrawArc($arcPen, [float]($size * 0.14), [float]($size * 0.14), [float]($size * 0.72), [float]($size * 0.72), 140.0, 120.0)
    $arcPen.Dispose()

    # 4. Kinetic shockwave energy trails behind heel
    $trailPen1 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 0, 242, 254), [float]($size * 0.012))
    $trailPen1.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $trailPen1.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($trailPen1, [float]($size * 0.12), [float]($size * 0.52), [float]($size * 0.26), [float]($size * 0.52))
    $g.DrawLine($trailPen1, [float]($size * 0.08), [float]($size * 0.58), [float]($size * 0.24), [float]($size * 0.58))
    $g.DrawLine($trailPen1, [float]($size * 0.14), [float]($size * 0.64), [float]($size * 0.27), [float]($size * 0.64))
    $trailPen1.Dispose()

    # 5. Smart Footwear Sole & Midsole (Translucent Illuminated Cyber Sole)
    # Sole outer glow
    $soleGlowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 0, 242, 254), [float]($size * 0.06))
    $soleGlowPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $soleGlowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $soleGlowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $soleGlowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $soleGlowPath.AddCurve(@(
        (New-Object System.Drawing.PointF([float]($size * 0.23), [float]($size * 0.62))),
        (New-Object System.Drawing.PointF([float]($size * 0.33), [float]($size * 0.67))),
        (New-Object System.Drawing.PointF([float]($size * 0.50), [float]($size * 0.65))),
        (New-Object System.Drawing.PointF([float]($size * 0.68), [float]($size * 0.69))),
        (New-Object System.Drawing.PointF([float]($size * 0.84), [float]($size * 0.58)))
    ))
    $g.DrawPath($soleGlowPen, $soleGlowPath)
    $soleGlowPen.Dispose()
    $soleGlowPath.Dispose()

    # Sole Solid Illuminated Body
    $solePath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $solePoints = @(
        (New-Object System.Drawing.PointF([float]($size * 0.22), [float]($size * 0.59))),
        (New-Object System.Drawing.PointF([float]($size * 0.24), [float]($size * 0.66))),
        (New-Object System.Drawing.PointF([float]($size * 0.35), [float]($size * 0.68))),
        (New-Object System.Drawing.PointF([float]($size * 0.50), [float]($size * 0.66))),
        (New-Object System.Drawing.PointF([float]($size * 0.68), [float]($size * 0.70))),
        (New-Object System.Drawing.PointF([float]($size * 0.84), [float]($size * 0.60))),
        (New-Object System.Drawing.PointF([float]($size * 0.85), [float]($size * 0.54))),
        (New-Object System.Drawing.PointF([float]($size * 0.75), [float]($size * 0.58))),
        (New-Object System.Drawing.PointF([float]($size * 0.52), [float]($size * 0.57))),
        (New-Object System.Drawing.PointF([float]($size * 0.36), [float]($size * 0.59))),
        (New-Object System.Drawing.PointF([float]($size * 0.25), [float]($size * 0.56)))
    )
    $solePath.AddPolygon($solePoints)

    # Cyan gradient sole fill
    $soleBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF([float]($size * 0.2), [float]($size * 0.6))),
        (New-Object System.Drawing.PointF([float]($size * 0.85), [float]($size * 0.6))),
        [System.Drawing.Color]::FromArgb(255, 0, 242, 254),
        [System.Drawing.Color]::FromArgb(255, 79, 172, 254)
    )
    $g.FillPath($soleBrush, $solePath)
    $soleBrush.Dispose()

    # Neon white core reflection line inside sole
    $soleCorePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(230, 255, 255, 255), [float]($size * 0.012))
    $soleCorePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $soleCorePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $soleCoreCurve = @(
        (New-Object System.Drawing.PointF([float]($size * 0.25), [float]($size * 0.61))),
        (New-Object System.Drawing.PointF([float]($size * 0.36), [float]($size * 0.63))),
        (New-Object System.Drawing.PointF([float]($size * 0.50), [float]($size * 0.61))),
        (New-Object System.Drawing.PointF([float]($size * 0.67), [float]($size * 0.64))),
        (New-Object System.Drawing.PointF([float]($size * 0.81), [float]($size * 0.56)))
    )
    $g.DrawCurve($soleCorePen, $soleCoreCurve)
    $soleCorePen.Dispose()

    # 6. Shoe Upper Body (High-Tech Aerodynamic Cyber Armor)
    $upperPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $upperPoints = @(
        (New-Object System.Drawing.PointF([float]($size * 0.22), [float]($size * 0.58))),
        (New-Object System.Drawing.PointF([float]($size * 0.24), [float]($size * 0.44))), # Heel counter
        (New-Object System.Drawing.PointF([float]($size * 0.32), [float]($size * 0.38))), # Ankle collar
        (New-Object System.Drawing.PointF([float]($size * 0.40), [float]($size * 0.40))), # Collar dip
        (New-Object System.Drawing.PointF([float]($size * 0.47), [float]($size * 0.32))), # High tongue
        (New-Object System.Drawing.PointF([float]($size * 0.62), [float]($size * 0.44))), # Throat / laces
        (New-Object System.Drawing.PointF([float]($size * 0.77), [float]($size * 0.50))), # Forefoot curve
        (New-Object System.Drawing.PointF([float]($size * 0.85), [float]($size * 0.54))), # Toe tip
        (New-Object System.Drawing.PointF([float]($size * 0.75), [float]($size * 0.58))),
        (New-Object System.Drawing.PointF([float]($size * 0.52), [float]($size * 0.57))),
        (New-Object System.Drawing.PointF([float]($size * 0.36), [float]($size * 0.59))),
        (New-Object System.Drawing.PointF([float]($size * 0.25), [float]($size * 0.56)))
    )
    $upperPath.AddPolygon($upperPoints)

    # Sleek dark cyber armor fill
    $upperBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF([float]($size * 0.4), [float]($size * 0.3))),
        (New-Object System.Drawing.PointF([float]($size * 0.5), [float]($size * 0.6))),
        [System.Drawing.Color]::FromArgb(255, 26, 34, 56),
        [System.Drawing.Color]::FromArgb(255, 14, 18, 30)
    )
    $g.FillPath($upperBrush, $upperPath)
    $upperBrush.Dispose()

    # Outer shoe neon rim stroke
    $upperRimPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 0, 242, 254), [float]($size * 0.008))
    $g.DrawPath($upperRimPen, $upperPath)
    $upperRimPen.Dispose()
    $upperPath.Dispose()

    # 7. Cyber Armor Facets & Panels
    # Heel Shield (Deep violet/magenta carbon plate)
    $heelShield = New-Object System.Drawing.Drawing2D.GraphicsPath
    $heelShield.AddPolygon(@(
        (New-Object System.Drawing.PointF([float]($size * 0.25), [float]($size * 0.45))),
        (New-Object System.Drawing.PointF([float]($size * 0.32), [float]($size * 0.40))),
        (New-Object System.Drawing.PointF([float]($size * 0.39), [float]($size * 0.48))),
        (New-Object System.Drawing.PointF([float]($size * 0.32), [float]($size * 0.57))),
        (New-Object System.Drawing.PointF([float]($size * 0.24), [float]($size * 0.55)))
    ))
    $heelBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF([float]($size * 0.25), [float]($size * 0.4))),
        (New-Object System.Drawing.PointF([float]($size * 0.35), [float]($size * 0.6))),
        [System.Drawing.Color]::FromArgb(255, 60, 20, 90),
        [System.Drawing.Color]::FromArgb(255, 24, 15, 45)
    )
    $g.FillPath($heelBrush, $heelShield)
    $heelStroke = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 247, 37, 133), [float]($size * 0.005))
    $g.DrawPath($heelStroke, $heelShield)
    $heelBrush.Dispose()
    $heelStroke.Dispose()
    $heelShield.Dispose()

    # Midfoot Cyber Exoskeleton Plate
    $midPlate = New-Object System.Drawing.Drawing2D.GraphicsPath
    $midPlate.AddPolygon(@(
        (New-Object System.Drawing.PointF([float]($size * 0.41), [float]($size * 0.42))),
        (New-Object System.Drawing.PointF([float]($size * 0.49), [float]($size * 0.36))),
        (New-Object System.Drawing.PointF([float]($size * 0.58), [float]($size * 0.46))),
        (New-Object System.Drawing.PointF([float]($size * 0.48), [float]($size * 0.56))),
        (New-Object System.Drawing.PointF([float]($size * 0.38), [float]($size * 0.54)))
    ))
    $midBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 32, 44, 72))
    $g.FillPath($midBrush, $midPlate)
    $midStroke = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180, 0, 242, 254), [float]($size * 0.005))
    $g.DrawPath($midStroke, $midPlate)
    $midBrush.Dispose()
    $midStroke.Dispose()
    $midPlate.Dispose()

    # Toe Speed Shield
    $toePlate = New-Object System.Drawing.Drawing2D.GraphicsPath
    $toePlate.AddPolygon(@(
        (New-Object System.Drawing.PointF([float]($size * 0.64), [float]($size * 0.46))),
        (New-Object System.Drawing.PointF([float]($size * 0.76), [float]($size * 0.50))),
        (New-Object System.Drawing.PointF([float]($size * 0.83), [float]($size * 0.54))),
        (New-Object System.Drawing.PointF([float]($size * 0.74), [float]($size * 0.57))),
        (New-Object System.Drawing.PointF([float]($size * 0.60), [float]($size * 0.54)))
    ))
    $toeBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 22, 30, 52))
    $g.FillPath($toeBrush, $toePlate)
    $toeStroke = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 247, 37, 133), [float]($size * 0.005))
    $g.DrawPath($toeStroke, $toePlate)
    $toeBrush.Dispose()
    $toeStroke.Dispose()
    $toePlate.Dispose()

    # 8. Glowing Cyber Laces (Energy Cables)
    $lacePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 0, 242, 254), [float]($size * 0.010))
    $lacePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $lacePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($lacePen, [float]($size * 0.44), [float]($size * 0.36), [float]($size * 0.48), [float]($size * 0.42))
    $g.DrawLine($lacePen, [float]($size * 0.48), [float]($size * 0.39), [float]($size * 0.53), [float]($size * 0.45))
    $g.DrawLine($lacePen, [float]($size * 0.53), [float]($size * 0.42), [float]($size * 0.58), [float]($size * 0.48))
    $g.DrawLine($lacePen, [float]($size * 0.58), [float]($size * 0.45), [float]($size * 0.64), [float]($size * 0.51))
    $lacePen.Dispose()

    # 9. Dynamic Stride AI Neon Circuitry Lines (Crossing the shoe body)
    $circuitPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 247, 37, 133), [float]($size * 0.007))
    $circuitPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $circuitPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $circuitCurve = @(
        (New-Object System.Drawing.PointF([float]($size * 0.28), [float]($size * 0.52))),
        (New-Object System.Drawing.PointF([float]($size * 0.42), [float]($size * 0.49))),
        (New-Object System.Drawing.PointF([float]($size * 0.56), [float]($size * 0.51))),
        (New-Object System.Drawing.PointF([float]($size * 0.72), [float]($size * 0.54)))
    )
    $g.DrawCurve($circuitPen, $circuitCurve)
    $circuitPen.Dispose()

    # 10. Central AI Microchip Nexus (Glowing Diamond on Quarter)
    $chipX = [float]($size * 0.46)
    $chipY = [float]($size * 0.47)
    $chipR = [float]($size * 0.04)

    # Chip glow halo
    $chipHalo = New-Object System.Drawing.Drawing2D.GraphicsPath
    $chipHalo.AddEllipse([float]($chipX - $chipR * 1.8), [float]($chipY - $chipR * 1.8), [float]($chipR * 3.6), [float]($chipR * 3.6))
    $chipPbg = New-Object System.Drawing.Drawing2D.PathGradientBrush($chipHalo)
    $chipPbg.CenterColor = [System.Drawing.Color]::FromArgb(200, 0, 242, 254)
    $chipPbg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 242, 254))
    $g.FillPath($chipPbg, $chipHalo)
    $chipPbg.Dispose()
    $chipHalo.Dispose()

    # Diamond chip body
    $chipPoly = @(
        (New-Object System.Drawing.PointF($chipX, [float]($chipY - $chipR))),
        (New-Object System.Drawing.PointF([float]($chipX + $chipR), $chipY)),
        (New-Object System.Drawing.PointF($chipX, [float]($chipY + $chipR))),
        (New-Object System.Drawing.PointF([float]($chipX - $chipR), $chipY))
    )
    $chipBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 6, 12, 28))
    $g.FillPolygon($chipBrush, $chipPoly)
    $chipBrush.Dispose()
    $chipPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 0, 242, 254), [float]($size * 0.006))
    $g.DrawPolygon($chipPen, $chipPoly)
    $chipPen.Dispose()

    # Core AI micro-dot
    $chipCoreBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
    $g.FillEllipse($chipCoreBrush, [float]($chipX - $size * 0.012), [float]($chipY - $size * 0.012), [float]($size * 0.024), [float]($size * 0.024))
    $chipCoreBrush.Dispose()

    # 11. Smart Footwear FSR Sensor Array Nodes (Heel, Midfoot, Metatarsal, Toe)
    $sensors = @(
        @{ X = [float]($size * 0.29); Y = [float]($size * 0.63); Label = "HEEL" },
        @{ X = [float]($size * 0.44); Y = [float]($size * 0.63); Label = "ARCH" },
        @{ X = [float]($size * 0.60); Y = [float]($size * 0.65); Label = "BALL" },
        @{ X = [float]($size * 0.76); Y = [float]($size * 0.61); Label = "TOE" }
    )

    foreach ($s in $sensors) {
        $sx = $s.X
        $sy = $s.Y
        $sr = [float]($size * 0.028)

        # Pulsing sensor glow
        $sHalo = New-Object System.Drawing.Drawing2D.GraphicsPath
        $sHalo.AddEllipse([float]($sx - $sr * 1.6), [float]($sy - $sr * 1.6), [float]($sr * 3.2), [float]($sr * 3.2))
        $sPbg = New-Object System.Drawing.Drawing2D.PathGradientBrush($sHalo)
        $sPbg.CenterColor = [System.Drawing.Color]::FromArgb(220, 247, 37, 133)
        $sPbg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 247, 37, 133))
        $g.FillPath($sPbg, $sHalo)
        $sPbg.Dispose()
        $sHalo.Dispose()

        # Sensor ring
        $sRingPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 255, 255), [float]($size * 0.005))
        $g.DrawEllipse($sRingPen, [float]($sx - $sr * 0.7), [float]($sy - $sr * 0.7), [float]($sr * 1.4), [float]($sr * 1.4))
        $sRingPen.Dispose()

        # Sensor vibrant core
        $sCenterBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 0, 242, 254))
        $g.FillEllipse($sCenterBrush, [float]($sx - $sr * 0.35), [float]($sy - $sr * 0.35), [float]($sr * 0.7), [float]($sr * 0.7))
        $sCenterBrush.Dispose()
    }

    # 12. Energy Tread Grip Light Bars (Under the sole)
    $treadPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 0, 242, 254), [float]($size * 0.008))
    $treadPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $treadPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    for ($i = 0; $i -lt 6; $i++) {
        $tx = [float]($size * (0.28 + $i * 0.09))
        $ty = [float]($size * (0.67 + ($i % 2) * 0.015))
        $g.DrawLine($treadPen, $tx, $ty, [float]($tx + $size * 0.02), [float]($ty + $size * 0.025))
    }
    $treadPen.Dispose()

    # 13. Dynamic High-Tech Top Branding Arc: "SMARTFOOTWEAR"
    # Small futuristic subtitle / badge styling
    $fontFamily = [System.Drawing.FontFamily]::GenericSansSerif
    $fontSize = [float]($size * 0.048)
    $font = New-Object System.Drawing.Font($fontFamily, $fontSize, [System.Drawing.FontStyle]::Bold)
    $text = "SMARTFOOTWEAR"
    $textSize = $g.MeasureString($text, $font)
    $textX = ($size - $textSize.Width) / 2.0
    $textY = [float]($size * 0.16)

    # Text cyan glow & shadow
    $shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 0, 242, 254))
    $g.DrawString($text, $font, $shadowBrush, [float]($textX), [float]($textY + $size * 0.003))
    $shadowBrush.Dispose()

    # Crisp white tech text
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
    $g.DrawString($text, $font, $textBrush, [float]$textX, [float]$textY)
    $textBrush.Dispose()
    $font.Dispose()

    # Bottom badge / AI Gait tracker accent
    $subFont = New-Object System.Drawing.Font($fontFamily, [float]($size * 0.028), [System.Drawing.FontStyle]::Bold)
    $subText = "AI GAIT INTELLIGENCE"
    $subSize = $g.MeasureString($subText, $subFont)
    $subX = ($size - $subSize.Width) / 2.0
    $subY = [float]($size * 0.81)

    $subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 0, 242, 254))
    $g.DrawString($subText, $subFont, $subBrush, [float]$subX, [float]$subY)
    $subBrush.Dispose()
    $subFont.Dispose()

    # 14. Kinetic Sparkles & Energy Stars
    $sparkles = @(
        @{ X = [float]($size * 0.78); Y = [float]($size * 0.34); R = [float]($size * 0.015); C = [System.Drawing.Color]::FromArgb(255, 0, 242, 254) },
        @{ X = [float]($size * 0.86); Y = [float]($size * 0.44); R = [float]($size * 0.010); C = [System.Drawing.Color]::FromArgb(255, 247, 37, 133) },
        @{ X = [float]($size * 0.18); Y = [float]($size * 0.36); R = [float]($size * 0.012); C = [System.Drawing.Color]::FromArgb(255, 0, 242, 254) },
        @{ X = [float]($size * 0.83); Y = [float]($size * 0.72); R = [float]($size * 0.011); C = [System.Drawing.Color]::FromArgb(255, 0, 242, 254) },
        @{ X = [float]($size * 0.16); Y = [float]($size * 0.70); R = [float]($size * 0.013); C = [System.Drawing.Color]::FromArgb(255, 247, 37, 133) }
    )

    foreach ($sp in $sparkles) {
        $spPen = New-Object System.Drawing.Pen($sp.C, [float]($size * 0.004))
        $g.DrawLine($spPen, [float]($sp.X - $sp.R * 2), [float]$sp.Y, [float]($sp.X + $sp.R * 2), [float]$sp.Y)
        $g.DrawLine($spPen, [float]$sp.X, [float]($sp.Y - $sp.R * 2), [float]$sp.X, [float]($sp.Y + $sp.R * 2))
        $spPen.Dispose()
        $spCore = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
        $g.FillEllipse($spCore, [float]($sp.X - $sp.R * 0.5), [float]($sp.Y - $sp.R * 0.5), [float]($sp.R), [float]($sp.R))
        $spCore.Dispose()
    }

    $g.Dispose()
    return $bmp
}

function Resize-And-Save {
    param(
        [System.Drawing.Bitmap]$sourceBmp,
        [int]$targetWidth,
        [int]$targetHeight,
        [string]$outputPath
    )
    $dir = [System.IO.Path]::GetDirectoryName($outputPath)
    if (-not [System.IO.Directory]::Exists($dir)) {
        [System.IO.Directory]::CreateDirectory($dir) | Out-Null
    }

    $resized = New-Object System.Drawing.Bitmap($targetWidth, $targetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $rg = [System.Drawing.Graphics]::FromImage($resized)
    $rg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $rg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $rg.DrawImage($sourceBmp, 0, 0, $targetWidth, $targetHeight)
    $rg.Dispose()

    $resized.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $resized.Dispose()
    Write-Host "Saved: $outputPath ($($targetWidth)x$($targetHeight))"
}

# --- Generate Master 1024x1024 Icon ---
Write-Host "Rendering Master 1024x1024 Smartfootwear icon..."
$master = Build-SmartFootwearIcon 1024
$master.Save("c:\Users\agast\stride_ai\smartfootwear_master_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Master icon created at c:\Users\agast\stride_ai\smartfootwear_master_icon.png"

# --- Export Android Mipmaps ---
$androidMap = @{
    "c:\Users\agast\stride_ai\android\app\src\main\res\mipmap-mdpi\ic_launcher.png" = 48
    "c:\Users\agast\stride_ai\android\app\src\main\res\mipmap-hdpi\ic_launcher.png" = 72
    "c:\Users\agast\stride_ai\android\app\src\main\res\mipmap-xhdpi\ic_launcher.png" = 96
    "c:\Users\agast\stride_ai\android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png" = 144
    "c:\Users\agast\stride_ai\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png" = 192
}

foreach ($item in $androidMap.GetEnumerator()) {
    Resize-And-Save $master $item.Value $item.Value $item.Key
}

# --- Export iOS AppIcon Assets ---
$iosMap = @{
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png" = 20
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png" = 40
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png" = 60
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png" = 29
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png" = 58
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png" = 87
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png" = 40
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png" = 80
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png" = 120
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png" = 120
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png" = 180
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png" = 76
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png" = 152
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png" = 167
    "c:\Users\agast\stride_ai\ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png" = 1024
}

foreach ($item in $iosMap.GetEnumerator()) {
    Resize-And-Save $master $item.Value $item.Value $item.Key
}

# --- Export Web Icons & Favicon ---
$webMap = @{
    "c:\Users\agast\stride_ai\web\icons\Icon-192.png" = 192
    "c:\Users\agast\stride_ai\web\icons\Icon-512.png" = 512
    "c:\Users\agast\stride_ai\web\icons\Icon-maskable-192.png" = 192
    "c:\Users\agast\stride_ai\web\icons\Icon-maskable-512.png" = 512
    "c:\Users\agast\stride_ai\web\favicon.png" = 48
}

foreach ($item in $webMap.GetEnumerator()) {
    Resize-And-Save $master $item.Value $item.Value $item.Key
}

$master.Dispose()
Write-Host "All icons generated successfully!"
