class String
  def pretty_print(pp)
    pp.text inspect.gsub(/\\n(?!")/, '\n" +'+"\n"+'"')
  end
end
