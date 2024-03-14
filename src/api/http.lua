function fetchJsonData(url)
  local response = http.get(url)
  if response then
    local responseData = response.readAll()
    response.close()
    return textutils.unserializeJSON(responseData)
  else
    print("Failed to fetch JSON data from the URL.")
    return nil
  end
end
