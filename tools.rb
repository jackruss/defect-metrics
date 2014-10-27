module Tools

def Tools.pluck(expression,string)
  arr1 = expression.split("((")
  before = arr1[0]
  arr2 = arr1[1].split("))")
  target = arr2[0]
  after = arr2[1]
  substring = string[/#{before}#{target}#{after}/]
  beginning = string[/#{before}#{target}/]
  beginning.sub(/#{before}/,"")
end


end
