tv4 = _require 'tv4'
loadScript './api-spec-converter.js'

WADLImporter = ->

    # Create Paw requests from a Swagger Request (object)
    @createPawRequest = (context, swaggerCollection, swaggerRequestPath, swaggerRequestMethod, swaggerRequestValue) ->

        if swaggerRequestValue.summary
          swaggerRequestTitle = swaggerRequestValue.summary
        else
          swaggerRequestTitle = swaggerRequestPath

        headers = {}
        queries = {}
        formData = {}
        body

        # Extract contentType from Consumes and add the first one to Headers
        if swaggerRequestValue.consumes
          for contentType in swaggerRequestValue.consumes
            headers["Content-Type"] = contentType
            break

        # Extract Headers and Query params
        for index, swaggerRequestParamValue of swaggerRequestValue.parameters

          # Add Queries
          if swaggerRequestParamValue.in == 'query' and swaggerRequestParamValue.type == 'string'
            queries[swaggerRequestParamValue.name] = swaggerRequestParamValue.name

          # Add Headers
          if swaggerRequestParamValue.in == 'header' and swaggerRequestParamValue.type == 'string'
            headers[swaggerRequestParamValue.name] = swaggerRequestParamValue.name

          # Add Url Encoded
          if swaggerRequestParamValue.in == 'formData' and swaggerRequestParamValue.type == 'string'
            formData[swaggerRequestParamValue.name] = swaggerRequestParamValue.name

          # Add Body
          if swaggerRequestParamValue.in == 'body' #Only string
            body = @json_from_definition_schema swaggerCollection, swaggerRequestParamValue.schema

        swaggerRequestUrl = @createSwaggerRequestUrl swaggerCollection, swaggerRequestPath, queries
        swaggerRequestMethod = swaggerRequestMethod.toUpperCase()

        # Create Paw request
        pawRequest = context.createRequest swaggerRequestTitle, swaggerRequestMethod, swaggerRequestUrl

        # Add Headers
        for key, value of headers
          pawRequest.setHeader key, value

        # Add Basic Auth if required
        pawRequest.setHeader "Authorization", "HTTP Basic Auth (Username/Password)" if @has_basic_auth swaggerCollection, swaggerRequestValue

        # Set raw body
        pawRequest.body = body if body

        # Set Form URL-Encoded body
        if Object.keys(formData).length > 0
            # Set Form URL-Encoded body
            if headers['Content-Type'] == "application/x-www-form-urlencoded"
              pawRequest.urlEncodedBody = formData
            # Set Multipart body
            else if headers['Content-Type'] == "multipart/form-data"
              pawRequest.multipartBody = formData

        return pawRequest

    @has_basic_auth = (swaggerCollection, swaggerRequestValue) ->
      if swaggerRequestValue.security
        for security in swaggerRequestValue.security
          for own key, value of security
            if swaggerCollection.securityDefinitions[key] and swaggerCollection.securityDefinitions[key].type == 'basic'
              return true
            break
      return false

    @json_from_definition_schema = (swaggerCollection, property, indent = 0) ->

        if property.type == 'string'
            s = "\"string\""
        else if property.type == 'integer'
            s = "0"
        else if property.type == 'boolean'
            s = "true"
        else if typeof(property) == 'object'
            indent_str = Array(indent + 1).join('    ')
            indent_str_children = Array(indent + 2).join('    ')

            if property.items
              property = property.items
              s = "[\n" +
                  "#{indent_str_children}#{@json_from_definition_schema(swaggerCollection, property, indent+1)}" +
                  "\n#{indent_str}]"
            else
              property = swaggerCollection.definitions[property["$ref"].split('/').pop()] if property["$ref"]
              property = property.properties if property.properties # Skip properties

              s = "{\n" +
                  ("#{indent_str_children}\"#{key}\" : #{@json_from_definition_schema(swaggerCollection, value, indent+1)}" for key, value of property).join(',\n') +
                  "\n#{indent_str}}"

        return s

    @createSwaggerRequestUrl = (swaggerCollection, swaggerRequestPath, queries) ->

        # Build swaggerRequestQueries
        if Object.keys(queries).length > 0
          swaggerRequestQueries = []

        for key, value of queries
          swaggerRequestQueries.push "#{key}=#{value}"

        swaggerRequestUrl = (if swaggerCollection.schemes then swaggerCollection.schemes[0] else 'http') +
          '://' +
          (swaggerCollection.host or 'echo.luckymarmot.com')

        # add basePath
        if swaggerCollection.basePath and swaggerCollection.basePath.length > 0
          basePath = swaggerCollection.basePath

          # make sure it starts with a /
          if basePath.indexOf('/') != 0
            basePath = '/' + basePath

          # make sure it doesn't end with a /
          if basePath.length > 0 and basePath[basePath.length - 1] == '/'
            basePath = basePath.substr(0, basePath.length - 1)
          swaggerRequestUrl += basePath

        # add path
        if not swaggerRequestPath or swaggerRequestPath.length == 0 or swaggerRequestPath[0] != '/'
          throw new Error "Invalid Swagger, path must begin with a /"
        swaggerRequestUrl += swaggerRequestPath

        if swaggerRequestQueries
          swaggerRequestUrl = swaggerRequestUrl + '?' + swaggerRequestQueries.join('&')

        return swaggerRequestUrl

    @createPawGroup = (context, swaggerCollection, swaggerRequestPathName, swaggerRequestPathValue) ->

        # Create Paw group
        pawGroup = context.createRequestGroup swaggerRequestPathName

        for own swaggerRequestMethod, swaggerRequestValue of swaggerRequestPathValue

            if swaggerRequestMethod.toLowerCase() == 'parameters'
              continue

            # Create a Paw request
            pawRequest = @createPawRequest context, swaggerCollection, swaggerRequestPathName, swaggerRequestMethod, swaggerRequestValue

            # Add request to root group
            pawGroup.appendChild pawRequest

        return pawGroup

    @importSwaggerCollection = (context, swaggerCollection) ->
        schema = readFile "schema.json"
        valid = tv4.validate swaggerCollection, JSON.parse(schema)

        if not valid
          throw new Error "Invalid Swagger file (invalid schema or schema version < 2.0): #{ tv4.error }"

        if swaggerCollection

          # Define host to localhost if not specified in file
          swaggerCollection.host = if swaggerCollection.host then swaggerCollection.host else 'localhost'

          # Create a PawGroup
          pawRootGroup = context.createRequestGroup swaggerCollection.info.title

          # Add Swagger groups
          for own swaggerRequestPathName, swaggerRequestPathValue of swaggerCollection.paths

            pawGroup = @createPawGroup context, swaggerCollection, swaggerRequestPathName, swaggerRequestPathValue

            # Add group to root
            pawRootGroup.appendChild pawGroup

          return true

    @importString = (context, string) ->
      completed = false
      options = {
        from: 'wadl',
        to: 'swagger_2',
        source: string,
      }
      APISpecConverter.convert options, (err, converted) =>
        if err
          throw new Error "Invalid WADL file (conversion to Swagger failed): #{ err.toString() }"

        swaggerCollection = converted.spec

        # set required info dictionary
        swaggerCollection.info = 
          title: converted.spec.host

        @importSwaggerCollection context, swaggerCollection
        completed = true
        return

      if not completed
        throw new Error "Import didn't completed on time (Paw doesn't support yet async import)"

      return true

    return

WADLImporter.identifier = "com.luckymarmot.PawExtensions.WADLImporter"
WADLImporter.title = "WADL Importer"

registerImporter WADLImporter
