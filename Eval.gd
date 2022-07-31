extends Node

const prefix = "!e"

var expr = Expression.new()

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
	bot.TOKEN = token
	bot.connect("bot_ready", self, "_on_bot_ready")
	bot.connect("message_create", self, "_on_message_create")
	bot.login()


func _on_bot_ready(bot: DiscordBot):
	print("Logged in as " + bot.user.username + "#" + bot.user.discriminator)
	print("Listening on " + str(bot.channels.size()) + " channels and " + str(bot.guilds.size()) + " guilds.")

func _on_message_create(bot: DiscordBot, message: Message, _channel: Dictionary):
	if message.author.bot or message.content.split(" ")[0] != prefix:
	   return
	var reg = RegEx.new()
	reg.compile("`+([^`]+)`+")
	var res = reg.search(message.content)
	var code = res.strings[1] if res else message.content.substr(len(prefix) + 1)
	var lines = code.split("\n")
	if res and lines[0] in ["swift", "py", "c", "c++"]:
		lines.remove(0)
		code = lines.join("\n")
	
	var skip = false
	var error = expr.parse(code, [])
	if error != OK:
		bot.send(message, str(expr.get_error_text()) if expr.get_error_text() else "null")
		skip = true

	if not skip:
		var result = expr.execute([], null, true)
		if not expr.has_execute_failed():
			bot.send(message, str(result) if result else "null")
			return
	bot.send(message, "Execution of \n```swift\n%s\n``` Has failed" % code + ( ": " + expr.get_error_text() if expr.get_error_text() else "."))

