# //twelvestone.com/forum_thread/view/29249

class PrefixCalcContext < Smelter::Context
  include Smelter::Combi
  # syntactic sugar. 
  # p :symbol, parser => def symbol; parser; end
  p :lparen, lit("(")
  p :rparen, lit(")")
  p :plus,   lit("+")
  p :minus,  lit("-")
  p :times,  lit("*")
  p :div,    lit("/")
  p :space,  lit(" ")

  # parses a digit ([0-9]+). Consumes whitespace
  # before and after the digit.
  def digit
    lambda {|sio|
      # create a function to check for a number
      # and return that number if it exists
      isnum     = lambda {|io|
        acc = nil
        c   = io.read 1
        while c =~ /[0-9]/ 
          if acc
            acc << c
          else
            acc = c
          end            
          c = io.read 1
        end
        io.pos -= 1 # backtrack after last (unsuccessful) read
        acc
      }
      # consume preceeding whitespace if any
      many(space).call sio 
      res = satisfy(isnum).call sio
      unless res.empty?
        # consume trailing whitespace if any
        many(space).call sio 
        # get the actual integer value of the result
        res.head.value = res.head.value.to_i 
      end
      res
    }
  end
    
  # A series of numbers and spaces e.g. "1 2 3 4 "
  def list_seq
    many(digit)
  end
  
  # the primitive functions of our mini language. defined as plus,
  # minus, times, and div
  def operator
    lambda {|sio|
      res = cor(cor(cor(plus,times),minus),div).call sio
      unless res.empty?
        case res.head.value 
           when "*" then oper = :*
           when "+" then oper = :+
           when "-" then oper = :-
           when "/" then oper = :/
        end
        list(ParseResult.new(sio, oper))
      else
        res
      end
    }
  end
  
  # an S expression. This is a recursive parser that is the guts of
  # our prefix calculator
  def sexp
    lambda {|sio|
      res  = lparen.call sio
      return res if res.empty?
      
      res  = operator.call sio
      oper = nil
      unless res.empty?
        oper = res.head.value
      else
        return res
      end
      space.call sio
      num    = many(cor(digit,sexp)).call sio
      total  = total_for oper, num
      rpres  = rparen.call sio
      unless rpres
        num    = many(cor(digit,sexp)).call sio
        total1 = total_for oper, num
        total  = total1.send(oper, total1)
      end
      list(ParseResult.new(sio, total))
    }
  end
  
  private
  
  # a helper function that enumerates through a result list and
  # accumulates the values of the result into an integer
  def total_for(oper, num)
    total = nil
    num.each {|num_res|
      val   = num_res.value
      total = val.shift
      val.each {|v|
        total = total.send oper, v
        }
    }
    total
  end
end



# And the demo:


sio       = StringIO.new "(+ 1 (* 22 2 (- 8 1)) 3 4 (* 2 2))"
prefix     = PrefixCalcContext.new
result    = prefix.sexp.call sio    
assert_equal 320, result.head.value
