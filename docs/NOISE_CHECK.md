# Noise / maths reference values

Captured from the JavaScript in `reference/ukiyo-river.html` by running the identical
functions under Node v20. `scripts/tools/noise_check.gd` reproduces these in GDScript and
fails loudly if any value drifts by more than 1e-9.

```
# reference values from reference/ukiyo-river.html (node v20.19.6)
## hash2(x,y)
hash2(0,0) = 0.000000000
hash2(1,0) = 0.508124461
hash2(0,1) = 0.768274554
hash2(-1,-1) = 0.062055925
hash2(37,-91) = 0.102077803
hash2(1234,5678) = 0.916257587
hash2(-2147483648,2147483647) = 0.538916953
## vnoise(x,y)
vnoise(0.5,0.5) = 0.334613735
vnoise(3.25,-7.75) = 0.169485628
vnoise(-12.125,4.5) = 0.874071849
vnoise(100.7,200.3) = 0.575413277
## fbm(x,y,o)
fbm(0.5,0.5,3) = 0.302268198
fbm(1.7,-2.3,5) = 0.456199046
fbm(-8.25,13.5,3) = 0.456711694
fbm(3.3,4.4,5) = 0.581323554
## mulberry32(20260923) first 8
rng[0] = 0.260265860
rng[1] = 0.044911657
rng[2] = 0.702738767
rng[3] = 0.785821498
rng[4] = 0.935177126
rng[5] = 0.909754414
rng[6] = 0.863882763
rng[7] = 0.221007573
## mulberry32(11) first 4
m11[0] = 0.511587049
m11[1] = 0.529946408
m11[2] = 0.608118564
m11[3] = 0.590157636
## riverX / riverSlope
riverX(-335) = 0.598427051  riverSlope(-335) = -0.227507602
riverX(-262) = -5.511954378  riverSlope(-262) = -0.040265127
riverX(-125) = -33.017525666  riverSlope(-125) = -0.047662400
riverX(0) = 8.672023669  riverSlope(0) = 0.338002215
riverX(92) = 15.995944294  riverSlope(92) = -0.039333044
riverX(175) = 22.782829353  riverSlope(175) = 0.162995749
riverX(322) = -11.016092138  riverSlope(322) = -0.469897569
## terrainH(x,z)
terrainH(0,0) = -3.200000000
terrainH(20,0) = -3.200000000
terrainH(40,-100) = 7.979142717
terrainH(-60,250) = 16.282005133
terrainH(150,-300) = 35.003358356
terrainH(300,300) = 93.407329834
terrainH(-450,-450) = 86.066607277
terrainH(17.5,-335) = -3.043401743
```
