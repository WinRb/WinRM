echo 'Getting the Environment'
echo '------------------------------------------------'
Get-ChildItem Env:

$diameter = 4.5

$area = [Math]::pow([Math]::PI * ($diameter/2), 2)

echo '------------------------------------------------'

echo 'Testing the Math library'
echo '------------------------------------------------'

echo "Circle Area: $area"
