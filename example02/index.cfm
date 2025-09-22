<cfinclude template="../credentials.cfm">

<cfinclude template="./menu.cfm">

<cfscript>
    /**
     * Function to call OpenAI Chat Completions API
     * @param messages Array of message objects with role and content (required)
     * @param model The OpenAI model to use (default: gpt-3.5-turbo)
     * @param maxTokens Maximum tokens in response (default: 150)
     * @param temperature Creativity level 0-1 (default: 0.7)
     * @param topP Nucleus sampling parameter 0-1 (default: 0.9)
     * @return struct containing success status, response data, and any error messages
     */
    function callOpenAI(
        required array messages,
        string model = "gpt-3.5-turbo",
        numeric maxTokens = 150,
        numeric temperature = 0.7,
        numeric topP = 0.9
    ) {
        var result = {
            success: false,
            response: "",
            fullResponse: "",
            error: "",
            statusCode: ""
        };
        
        try {
            // Validate messages array
            if (!arrayLen(arguments.messages)) {
                result.error = "Messages array cannot be empty";
                return result;
            }
            
            // Validate message structure
            for (var i = 1; i <= arrayLen(arguments.messages); i++) {
                var msg = arguments.messages[i];
                if (!structKeyExists(msg, "role") || !structKeyExists(msg, "content")) {
                    result.error = "Each message must have 'role' and 'content' properties";
                    return result;
                }
                if (!listContains("system,user,assistant", msg.role)) {
                    result.error = "Message role must be 'system', 'user', or 'assistant'";
                    return result;
                }
            }
            
            // API Configuration
            var apiUrl = "https://api.openai.com/v1/chat/completions";
            
            // Request payload
            var requestData = {
                "model": arguments.model,
                "messages": arguments.messages,
                "max_tokens": arguments.maxTokens,
                "temperature": arguments.temperature,
                "top_p": arguments.topP
            };
            
            // Convert to JSON
            var jsonPayload = serializeJSON(requestData);
            
            cfhttp(
                url=apiUrl,
                method="POST",
                result="httpResponse"
            ) {
                cfhttpparam(name="Content-Type", type="header", value="application/json");
                cfhttpparam(name="Authorization", type="header", value="Bearer #apiKey#");
                cfhttpparam(name="body", type="body", value=jsonPayload);
            }

            var apiResponse = httpResponse;

            // Store status and full response
            result.statusCode = apiResponse.statusCode;
            result.fullResponse = apiResponse.fileContent;
            
            // Check if successful
            if (apiResponse.statusCode == "200 OK") {
                var responseData = deserializeJSON(apiResponse.fileContent);
                
                if (structKeyExists(responseData, "choices") && arrayLen(responseData.choices) > 0) {
                    result.success = true;
                    result.response = responseData.choices[1].message.content;
                } else {
                    result.error = "No response content found in API response";
                }
            } else {
                result.error = "API Error - Status: " & apiResponse.statusCode;
            }
            
        } catch (any e) {
            result.error = "Exception occurred: " & e.message;
        }
        
        return result;
    }
    
    if (form.keyExists("question")) {
        // Prompt 1
        prompt01 = {};
        prompt01.messages = [
            {
                "role": "user",
                "content": "
                    Your task is to answer questions factually about a food menu, provided below and delimited by +++++. The user request is provided here: {request}

                    Step 1: The first step is to check if the user is asking a question related to any type of food (even if that food item is not on the menu). If the question is about any type of food, we move on to Step 2 and ignore the rest of Step 1. If the question is not about food, then we send a response: 'Sorry! I cannot help with that. Please let me know if you have a question about our food menu.'

                    Step 2: In this step, we check that the user question is relevant to any of the items on the food menu. You should check that the food item exists in our menu first. If it doesn't exist then send a kind response to the user that the item doesn't exist in our menu and then include a list of available but similar food items without any other details (e.g., price). The food items available are provided below and delimited by +++++:

                    +++++
                    #menu#
                    +++++

                    Step 3: If the item exists in our food menu and the user is requesting specific information, provide that relevant information to the user using the food menu. Make sure to use a friendly tone and keep the response concise.

                    Perform the following reasoning steps to send a response to the user:

                    Step 1: <Step 1 reasoning>

                    Step 2: <Step 2 reasoning>

                    Response to the user (only output the final response): <response to user>
                "
            }
            , {
                "role": "user",
                "content": #form.question#
            }
        ];
        
        prompt01.apiResult = callOpenAI(
            messages = prompt01.messages,
            model = "gpt-3.5-turbo",
            maxTokens = 150,
            temperature = 0.7,
            topP = 0.9
        );

        // Prompt 2
        prompt02 = {};
        prompt02.messages = [
            {
                "role": "user",
                "content": "
                    Extract the final response from the text delimited by +++.

                    +++
                    #prompt01.apiResult.response#
                    +++

                    Only output what comes after 'Response to the user:'.
                "
            }
        ];
        
        prompt02.apiResult = callOpenAI(
            messages = prompt02.messages,
            model = "gpt-3.5-turbo",
            maxTokens = 150,
            temperature = 0.7,
            topP = 0.9
        );

        // Prompt 3
        prompt03 = {};
        prompt03.messages = [
            {
                "role": "user",
                "content": "
                    Perform the following refinement steps on the final output delimited by +++

                    1). Shorten the text to one sentence
                    2). Use a friendly tone

                    +++
                    #prompt02.apiResult.response#
                    +++
                "
            }
        ];
        
        prompt03.apiResult = callOpenAI(
            messages = prompt03.messages,
            model = "gpt-4",
            maxTokens = 150,
            temperature = 0.7,
            topP = 0.9
        );
        
        // Display results
        writeOutput("<h2>OpenAI Response:</h2>");
        if (prompt01.apiResult.success) {
            writeOutput("<h3>Prompt 1:</h3>");
            writeOutput("<p>" & encodeForHTML(prompt01.apiResult.response) & "</p>");
        } else {
            writeOutput("<h2>Error:</h2>");
            writeOutput("<p>" & encodeForHTML(prompt01.apiResult.error) & "</p>");
        }
        if (prompt02.apiResult.success) {
            writeOutput("<h3>Prompt 2:</h3>");
            writeOutput("<p>" & encodeForHTML(prompt02.apiResult.response) & "</p>");
        } else {
            writeOutput("<h2>Error:</h2>");
            writeOutput("<p>" & encodeForHTML(prompt02.apiResult.error) & "</p>");
        }
        if (prompt03.apiResult.success) {
            writeOutput("<h3>Prompt 3:</h3>");
            writeOutput("<p>" & encodeForHTML(prompt03.apiResult.response) & "</p>");
        } else {
            writeOutput("<h2>Error:</h2>");
            writeOutput("<p>" & encodeForHTML(prompt03.apiResult.error) & "</p>");
        }
        
        // Optional: Display full response for debugging
        writeOutput("<h3>Full API Response (for debugging):</h3>");
        writeOutput("<h4>Prompt 1:</h4>");
        writeOutput("<pre>" & encodeForHTML(prompt01.apiResult.fullResponse) & "</pre>");
        writeOutput("<h4>Prompt 2:</h4>");
        writeOutput("<pre>" & encodeForHTML(prompt02.apiResult.fullResponse) & "</pre>");
        writeOutput("<h4>Prompt 3:</h4>");
        writeOutput("<pre>" & encodeForHTML(prompt03.apiResult.fullResponse) & "</pre>");
            
    }
</cfscript>

<cfif !form.keyExists("question")>
    <form method="post" action="##">
        <label for="question">Enter your question about the menu:</label><br>
        <input type="text" id="question" name="question" size="60" required><br><br>
        <input type="submit" value="Submit">
    </form>
</cfif>