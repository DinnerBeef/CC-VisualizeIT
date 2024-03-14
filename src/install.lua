-- Function to download a file from a URL and save it locally
function downloadFile(url, path)
  local request = http.get(url)
  if request then
    local response = request.readAll()
    request.close()

    local file = fs.open(path, "w")
    file.write(response)
    file.close()
    return true
  else
    print("Failed to download file from URL: " .. url)
    return false
  end
end

-- Function to recursively download files and directories from a GitHub repository
function getGit(github_repo_path, local_folder, path)
  local github_api_url = "https://api.github.com/repos/" .. github_repo_path .. "/contents/" .. path
  local response = http.get(github_api_url)

  if response then
    local files = textutils.unserializeJSON(response.readAll())
    response.close()

    if files then
      -- Delete all existing files and folders in the local folder
      if fs.exists(local_folder) then
        for _, file in ipairs(fs.list(local_folder)) do
          fs.delete(fs.combine(local_folder, file))
        end
      end

      for _, item in ipairs(files) do
        if item.type == "file" and item.path:match("%.lua$") then
          local fileUrl = item.download_url
          local localPath = fs.combine(local_folder, fs.getName(item.path))
          downloadFile(fileUrl, localPath)
          print("Downloaded: " .. item.path)
        elseif item.type == "dir" then
          local dirPath = fs.combine(local_folder, fs.getName(item.path))
          fs.makeDir(dirPath)
          print("Created directory: " .. item.path)
          getGit(github_repo_path, dirPath, item.path)
        end
      end
    else
      print("Failed to parse GitHub response.")
    end
  else
    print("Failed to access GitHub API.")
  end
end

-- Main program starts here
print("Installing CC-VisualizeIT")
getGit("DinnerBeef/CC-VisualizeIT", "", "src")
