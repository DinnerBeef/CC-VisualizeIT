function playSoundAllSpeakers(sound)
  local dfpwm = require("cc.audio.dfpwm")
  local speakers = { peripheral.find("speaker") }
  local decoder = dfpwm.make_decoder()
  local filePath = "data/sounds/" .. sound .. ".dfpwm"
  print("Playing sound from file: " .. filePath)
  for chunk in io.lines("data/sounds/" .. sound .. ".dfpwm", 16 * 1024) do
    local buffer = decoder(chunk)

    for _, speaker in ipairs(speakers) do
      while not speaker.playAudio(buffer) do
        os.pullEvent("speaker_audio_empty")
      end
    end
  end
  return true
end
