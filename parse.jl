# Copyright (c) 2022 Joey Herguth
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

macro and()
	true
end
macro and(a, d...)
	:($a ? @and($(d...)) : false)
end

macro or()
	false
end
macro or(a, d...)
	:($(esc(a)) ? true : @or($(esc.(d)...)))
end

mutable struct ParseStream
	const string::String
	index::UInt64
	const length::UInt64
end

Base.copy(stream::ParseStream) = ParseStream(stream.string, stream.index, stream.length)

struct Sym
    
end

Ast = Union{Number,String,Sym,Vector,Nothing}

struct ParseResult
	ast::Ast
	stream::ParseStream
	success::Bool
end

function getChar(stream)
	if stream.index <= stream.length
		char = stream.string[stream.index]
		stream.index += 1
		return (char, true)
	else
		return (nothing, false)
	end
end

function parseWhitespace(stream)
	startStream = copy(stream)
	while true
        lastStream = copy(stream)
		(char, success) = getChar(stream)
		if !success
			return ParseResult(nothing, lastStream, true)
		end
		if !isspace(char)
			return ParseResult(nothing, lastStream, true)
		end
	end
end

function parseNumber(stream)
	startStream = copy(stream)
	(digit, success) = getChar(stream)
	if @or(!success, !isdigit(digit))
		return ParseResult(nothing, startStream, false)
	end
	number = convert(Number, (digit - '0'))
	while true
        lastStream = copy(stream)
		(digit, success) = getChar(stream)
		if @or(!success, !isdigit(digit))
			return ParseResult(number, lastStream, true)
		end
		number = 10*number + convert(Number, digit - '0')
	end
end

function parseSymbol(stream)
	startStream = copy(stream)
    specialChars = "()"
    isSymbolChar(char) = !(isspace(char) || (char in specialChars))
	(digit, success) = getChar(stream)
	if @or(!success, !isSymbolChar(digit))
		return ParseResult(nothing, startStream, false)
	end
	number = convert(Number, (digit - '0'))
	while true
        lastStream = copy(stream)
		(digit, success) = getChar(stream)
		if @or(!success, !isdigit(digit))
			return ParseResult(number, lastStream, true)
		end
		number = 10*number + convert(Number, digit - '0')
	end
end

function parseList(stream)
	startStream = copy(stream)
    # Open parenthesis
	(openParen, success) = getChar(stream)
	if @or(!success, openParen != '(')
		return ParseResult(nothing, startStream, false)
	end
    list = []
	while true
        # White space
        result = parseWhitespace(stream)
        stream = result.stream
        # Close parenthesis
        lastStream = copy(stream)
	    (closeParen, success) = getChar(stream)
	    if !success
		    return ParseResult(nothing, startStream, false)
	    end
	    if closeParen == ')'
		    return ParseResult(list, stream, true)
	    end
        stream = lastStream
        # Expression
        result = parseExpression(stream)
		if !result.success
			return ParseResult(nothing, startStream, false)
		end
        append!(list, result.ast)
        stream = result.stream
	end
end

function parseExpression(stream)
	local result = parseWhitespace(stream)
	if !result.success
		return result
	end
    parsers = (parseNumber, parseSymbol, parseList)
    for parser in parsers
        result = parser(result.stream)
        if result.success
            return result
        end
    end
    return result
end

function readRepl(str)
	(; ast, stream, success) = parseExpression(ParseStream(str, 1, length(str)))
end
