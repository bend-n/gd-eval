extends Node

const prefix := "!e"

var expr := Expression.new()

const PRINT_FUNCS = {
	"print": "",
	"prints": " ",
	"printt": "\\t",
	"printraw": "",
}

const BLACKLISTED_OBJS = [
	"OS.",
	"File.",
	"GDScript.",
	"ClassDB.",
	"Expression.",
]

var script_append := "\n#----INSERTED-----#\n\nvar output: String"

const print_func_template := """
func {name}(arg1 = '', arg2 = '', arg3 = '', arg4 = '', arg5 = '', arg6 = '', arg7 = '', arg8 = '', arg9 = '') -> void:
	# Also call the built-in printing function
	{name}(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
	for argument in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9]:
		output += str(argument) + '{separator}'
	output += '{end}'
"""

var output_message = "Output: ```%s```"

var func_replacements = [
	[compile("print\\s*\\("), "self.print("],
	[compile("prints\\s*\\("), "self.prints("],
	[compile("printt\\s*\\("), "self.printt("],
	[compile("printraw\\s*\\("), "self.printraw("],
]


func compile(source: String) -> RegEx:
	var reg := RegEx.new()
	reg.compile(source)
	return reg


func _ready():
	var bot := DiscordBot.new()
	add_child(bot)
	var file = File.new()
	var err = file.open("res://token", File.READ)
	var token
	if err == OK:
		token = file.get_as_text()
	elif OS.has_environment("TOKEN"):
		token = OS.get_environment("TOKEN")
	else:
		push_error("token missing")
	file.close()
	bot.TOKEN = token
	bot.connect("bot_ready", self, "_on_bot_ready")
	bot.connect("message_create", self, "_on_message_create")
	bot.login()
	for print_func in PRINT_FUNCS:
		script_append += print_func_template.format(
			{
				name = print_func,
				separator = PRINT_FUNCS[print_func],
				end = "" if print_func == "printraw" else "\\n",
			}
		)


func _on_bot_ready(bot: DiscordBot):
	bot.set_presence({"activity": {"type": "Game", "name": "Evaluating GDScript"}})
	print("Logged in as " + bot.user.username + "#" + bot.user.discriminator)
	print("Listening on " + str(bot.channels.size()) + " channels and " + str(bot.guilds.size()) + " guilds.")


func _on_message_create(bot: DiscordBot, message: Message, _channel: Dictionary):
	var split = message.content.split(" ")
	if message.author.bot or not prefix in split[0]:
		return
	var reg := compile("`+([^`]+)`+")
	var res = reg.search(message.content)
	var code: String = res.strings[1] if res else PoolStringArray(Array(split).slice(1, len(split))).join(" ")
	var lines = code.split("\n")
	if res and lines[0] in ["swift", "py", "c", "c++"]:
		lines.remove(0)
		code = lines.join("\n")

	for b in BLACKLISTED_OBJS:
		code = code.replace(b, "Node.")

	code = code.strip_edges()

	var original_code = code  # save it for later

	var error
	if lines.size() > 1 or "." in code:
		if code.find("func _ready()") == -1:
			code = "func _ready():\n" + code.indent("\t") + "\n"

		if not "extends" in lines[0]:
			code = "extends Node\n" + code

		for row in func_replacements:
			code = row[0].sub(code, row[1], true)

		code += script_append

		var script := GDScript.new()
		script.source_code = code
		error = script.reload()
		if error == OK:
			var instance: Node = script.new()
			if is_instance_valid(instance):
				add_child(instance)
				yield(get_tree(), "idle_frame")
				var o = instance.output.strip_edges()
				bot.reply(message, output_message % (o if o else "null"))
				instance.queue_free()
				return
	else:
		var e: int = expr.parse(code, [])

		if e == OK:
			var o = str(expr.execute([], null, true))
			if not expr.has_execute_failed():
				bot.reply(message, output_message % (o if o else "null"))
				return
		error = expr.get_error_text()

	bot.reply(message, "Execution of \n```swift\n%s\n``` Has failed. Error: %s" % [original_code, error])
