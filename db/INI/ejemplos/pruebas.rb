=begin
def boleto_ganador?(a)
    bg=[]
    (1..6).each do |i|
    	bg[i]=rand(21)
    end
    puts "el boleto ganador es #{bg.to_s}"
    if a==bg then
    	puts 'boleto ganador bg=' + bg.to_s + ' a=' + a.to_s
    end 	
 end
    

boleto_ganador?([1,2,3,4,5,6])
=end

puts 'Introduzca una clave'
k=gets
puts 'introduzca un valor'
v=gets

diccionario={k=>v}
puts 'diccionario=' + diccionario.to_s
