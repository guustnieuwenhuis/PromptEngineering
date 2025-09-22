<cfinclude template="../credentials.cfm">

<cfscript>
    // OpenAI API Configuration
    apiUrl = "https://api.openai.com/v1/chat/completions";
    
    // Request payload for OpenAI Chat Completions API
    requestData = {
        "model": "gpt-3.5-turbo",
        "messages": [
            {
                "role": "system",
                "content": "You are a helpful assistant knowledgeable about ColdFusion and web development history."
            },
            {
                "role": "user",
                "content": "When was the first version of Adobe ColdFusion released?"
            }
        ],
        "max_tokens": 150,
        "temperature": 0.7,
        "top_p": 0.9
    };
    
    // Convert to JSON
    jsonPayload = serializeJSON(requestData);
    
    cfhttp(
        url=apiUrl,
        method="POST",
        result="httpResponse"
    ) {
        cfhttpparam(name="Content-Type", type="header", value="application/json");
        cfhttpparam(name="Authorization", type="header", value="Bearer #apiKey#");
        cfhttpparam(name="body", type="body", value=jsonPayload);
    }

    apiResponse = httpResponse;

    // Check if the API call was successful
    if (apiResponse.statusCode == "200 OK") {
        // Parse the JSON response
        responseData = deserializeJSON(apiResponse.fileContent);
        
        // Extract the AI's response
        if (structKeyExists(responseData, "choices") && arrayLen(responseData.choices) > 0) {
            aiResponse = responseData.choices[1].message.content;
            writeOutput("<h2>OpenAI Response:</h2>");
            writeOutput("<p>" & encodeForHTML(aiResponse) & "</p>");
        } else {
            writeOutput("<p>Error: No response content found in API response.</p>");
        }
        
        // Optional: Display full response for debugging
        writeOutput("<h3>Full API Response (for debugging):</h3>");
        writeOutput("<pre>" & encodeForHTML(apiResponse.fileContent) & "</pre>");
        
    } else {
        // Handle API errors
        writeOutput("<h2>API Error:</h2>");
        writeOutput("<p>Status Code: " & encodeForHTML(apiResponse.statusCode) & "</p>");
        writeOutput("<p>Response: " & encodeForHTML(apiResponse.fileContent) & "</p>");
    }
</cfscript>

<!--- Additional information about the request --->
<hr>
<h3>Request Details:</h3>
<p><strong>API Endpoint:</strong> <cfoutput>#encodeForHTML(apiUrl)#</cfoutput></p>
<p><strong>Model:</strong> gpt-3.5-turbo</p>
<p><strong>Prompt:</strong> When was the first version of Adobe ColdFusion released?</p>
<p><strong>Request Payload:</strong></p>
<pre><cfoutput>#encodeForHTML(jsonPayload)#</cfoutput></pre>
