local function switch(t)
  t.case = function (self, arg1, arg2, arg3)
    local f = self[arg1] or self.default
    if f then
      if type(f)=="function" then
        f(arg2, arg3, self)
      else
        error("case "..tostring(arg1).." not a function")
      end
    end
  end
  return t
end

return switch
