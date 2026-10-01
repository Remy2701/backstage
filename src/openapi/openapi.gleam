import dynamic/spec
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/uri.{type Uri}

fn uri_to_spec(uri: Uri) -> spec.Spec {
  spec.string(uri.to_string(uri))
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                      Potential Reference                                      //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type OrRef(a) {
  Ref(String)
  Value(a)
}

fn or_ref_to_spec(
  or_ref: OrRef(a),
  value_to_spec: fn(a) -> spec.Spec,
) -> spec.Spec {
  case or_ref {
    Ref(ref) -> spec.object([#("$ref", spec.string(ref))])
    Value(value) -> value_to_spec(value)
  }
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        License Object                                         //
//                                       ––––––––––––––––                                        //
//                     https://swagger.io/specification/v3.2/#license-object                     //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type License {
  License(name: String, identifier: Option(String), url: Option(Uri))
}

fn license_to_spec(license: License) -> spec.Spec {
  spec.object([
    #("name", spec.string(license.name)),
    #("identifier", spec.nullable(license.identifier, spec.string)),
    #("url", spec.nullable(license.url, uri_to_spec)),
  ])
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type LicenseNS {
  LicenseNS(to_spec: fn(License) -> spec.Spec)
}

pub const license = LicenseNS(to_spec: license_to_spec)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Contact Object                                         //
//                                       ––––––––––––––––                                        //
//                     https://swagger.io/specification/v3.2/#contact-object                     //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Contact {
  Contact(name: Option(String), url: Option(Uri), email: Option(String))
}

fn contact_to_spec(contact: Contact) -> spec.Spec {
  spec.object([
    #("name", spec.nullable(contact.name, spec.string)),
    #("url", spec.nullable(contact.url, uri_to_spec)),
    #("email", spec.nullable(contact.email, spec.string)),
  ])
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type ContactNS {
  ContactNS(to_spec: fn(Contact) -> spec.Spec)
}

pub const contact = ContactNS(to_spec: contact_to_spec)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Info Object                                          //
//                                         –––––––––––––                                         //
//                      https://swagger.io/specification/v3.2/#info-object                       //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Info {
  Info(
    title: String,
    summary: Option(String),
    description: Option(String),
    terms_of_service: Option(Uri),
    contact: Option(Contact),
    license: Option(License),
    version: String,
  )
}

fn info_to_spec(info: Info) -> spec.Spec {
  spec.object([
    #("title", spec.string(info.title)),
    #("summary", spec.nullable(info.summary, spec.string)),
    #("description", spec.nullable(info.description, spec.string)),
    #("termsOfService", spec.nullable(info.terms_of_service, uri_to_spec)),
    #("contact", spec.nullable(info.contact, contact.to_spec)),
    #("license", spec.nullable(info.license, license.to_spec)),
    #("version", spec.string(info.version)),
  ])
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type InfoNS {
  InfoNS(to_spec: fn(Info) -> spec.Spec)
}

pub const info = InfoNS(to_spec: info_to_spec)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                    Server Variable Object                                     //
//                                   ––––––––––––––––––––––––                                    //
//                 https://swagger.io/specification/v3.2/#server-variable-object                 //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type ServerVariable {
  ServerVariable(
    default: String,
    description: Option(String),
    enum: List(String),
  )
}

fn server_variable_to_spec(server_variable: ServerVariable) -> spec.Spec {
  spec.object([
    #("default", spec.string(server_variable.default)),
    #("description", spec.nullable(server_variable.description, spec.string)),
    #("enum", spec.array_of(server_variable.enum, spec.string)),
  ])
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type ServerVariableNS {
  ServerVariableNS(to_spec: fn(ServerVariable) -> spec.Spec)
}

pub const server_variable = ServerVariableNS(to_spec: server_variable_to_spec)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                         Server Object                                         //
//                                        –––––––––––––––                                        //
//                     https://swagger.io/specification/v3.2/#server-object                      //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Server {
  Server(
    url: Uri,
    description: Option(String),
    name: Option(String),
    variables: List(#(String, ServerVariable)),
  )
}

fn server_to_spec(server: Server) -> spec.Spec {
  spec.object([
    #("url", uri_to_spec(server.url)),
    #("description", spec.nullable(server.description, spec.string)),
    #("name", spec.nullable(server.name, spec.string)),
    #(
      "variables",
      spec.array_of(server.variables, fn(entry) {
        spec.object([
          #("name", spec.string(entry.0)),
          #("variable", server_variable_to_spec(entry.1)),
        ])
      }),
    ),
  ])
}

fn server_description(server: Server, description: String) -> Server {
  Server(..server, description: Some(description))
}

fn server_name(server: Server, name: String) -> Server {
  Server(..server, name: Some(name))
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type ServerNS {
  ServerNS(
    to_spec: fn(Server) -> spec.Spec,
    description: fn(Server, String) -> Server,
    name: fn(Server, String) -> Server,
  )
}

pub const server = ServerNS(
  to_spec: server_to_spec,
  description: server_description,
  name: server_name,
)

pub type ExternalDocs {
  ExternalDocs(description: Option(String), url: Uri)
}

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        Schema Object                                          //
//                                       –––––––––––––––                                         //
//                     https://swagger.io/specification/v3.2/#schema-object                      //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Schema {
  Schema(
    type_: List(String),
    format: Option(String),
    default: Option(spec.Spec),
    items: Option(Schema),
    properties: List(#(String, Schema)),
    enum: List(String),
    required: List(String),
    pattern: Option(String),
    examples: List(spec.Spec),
  )
}

fn schema_create(type_: String) -> Schema {
  Schema(
    type_: [type_],
    format: None,
    default: None,
    items: None,
    properties: [],
    enum: [],
    required: [],
    pattern: None,
    examples: [],
  )
}

fn schema_to_spec(schema: Schema) -> spec.Spec {
  spec.object([
    #("type", case schema.type_ {
      [] -> spec.array([])
      [single] -> spec.string(single)
      _ -> spec.array_of(schema.type_, spec.string)
    }),
    #("format", spec.nullable(schema.format, spec.string)),
    #("default", spec.nullable(schema.default, function.identity)),
    #("items", spec.nullable(schema.items, schema_to_spec)),
    #(
      "properties",
      schema.properties
        |> spec.none_if_empty
        |> spec.nullable(spec.object_of_tuple(_, schema_to_spec)),
    ),
    #(
      "required",
      schema.required
        |> spec.none_if_empty
        |> spec.nullable(spec.array_of(_, spec.string)),
    ),
    #("pattern", spec.nullable(schema.pattern, spec.string)),
    #(
      "enum",
      schema.enum
        |> spec.none_if_empty
        |> spec.nullable(spec.array_of(_, spec.string)),
    ),
    #(
      "examples",
      schema.examples
        |> spec.none_if_empty
        |> spec.nullable(spec.array),
    ),
  ])
}

fn schema_or(schema: Schema, type_: String) -> Schema {
  Schema(..schema, type_: list.append(schema.type_, [type_]))
}

fn schema_format(schema: Schema, format: String) -> Schema {
  Schema(..schema, format: Some(format))
}

fn schema_default(schema: Schema, default: spec.Spec) -> Schema {
  Schema(..schema, default: Some(default))
}

fn schema_pattern(schema: Schema, pattern: String) -> Schema {
  Schema(..schema, pattern: Some(pattern))
}

fn schema_items(
  schema: Schema,
  type_: String,
  builder: fn(Schema) -> Schema,
) -> Schema {
  Schema(..schema, items: Some(builder(schema_create(type_))))
}

fn schema_property(
  schema: Schema,
  name: String,
  type_: String,
  builder: fn(Schema) -> Schema,
) -> Schema {
  Schema(
    ..schema,
    properties: list.append(schema.properties, [
      #(name, builder(schema_create(type_))),
    ]),
  )
}

fn schema_required(schema: Schema, required: String) -> Schema {
  Schema(..schema, required: list.append(schema.required, [required]))
}

fn schema_enum(schema: Schema, enum: String) -> Schema {
  Schema(..schema, enum: list.append(schema.enum, [enum]))
}

fn schema_example(schema: Schema, example: spec.Spec) -> Schema {
  Schema(..schema, examples: list.append(schema.examples, [example]))
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type SchemaNS {
  SchemaNS(
    to_spec: fn(Schema) -> spec.Spec,
    or: fn(Schema, String) -> Schema,
    format: fn(Schema, String) -> Schema,
    default: fn(Schema, spec.Spec) -> Schema,
    items: fn(Schema, String, fn(Schema) -> Schema) -> Schema,
    property: fn(Schema, String, String, fn(Schema) -> Schema) -> Schema,
    required: fn(Schema, String) -> Schema,
    enum: fn(Schema, String) -> Schema,
    pattern: fn(Schema, String) -> Schema,
    example: fn(Schema, spec.Spec) -> Schema,
  )
}

pub const schema = SchemaNS(
  to_spec: schema_to_spec,
  or: schema_or,
  format: schema_format,
  default: schema_default,
  items: schema_items,
  property: schema_property,
  required: schema_required,
  enum: schema_enum,
  pattern: schema_pattern,
  example: schema_example,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Parameter Object                                        //
//                                      ––––––––––––––––––                                       //
//                    https://swagger.io/specification/v3.2/#parameter-object                    //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type ParameterIn {
  ParameterInQuery
  ParameterInQueryString
  ParameterInHeader
  ParameterInPath
  ParameterInCookie
}

fn parameter_in_to_spec(parameter_in: ParameterIn) -> spec.Spec {
  case parameter_in {
    ParameterInQuery -> spec.string("query")
    ParameterInQueryString -> spec.string("queryString")
    ParameterInHeader -> spec.string("header")
    ParameterInPath -> spec.string("path")
    ParameterInCookie -> spec.string("cookie")
  }
}

pub type Parameter {
  Parameter(
    name: String,
    in: ParameterIn,
    description: Option(String),
    required: Bool,
    deprecated: Bool,
    allow_empty_value: Bool,
    schema: Option(Schema),
  )
}

fn parameter_to_spec(parameter: Parameter) -> spec.Spec {
  spec.object([
    #("name", spec.string(parameter.name)),
    #("in", parameter_in_to_spec(parameter.in)),
    #("description", spec.nullable(parameter.description, spec.string)),
    #("required", spec.boolean(parameter.required)),
    #("deprecated", spec.boolean(parameter.deprecated)),
    #("allowEmptyValue", spec.boolean(parameter.allow_empty_value)),
    #("schema", spec.nullable(parameter.schema, schema_to_spec)),
  ])
}

fn parameter_description(
  parameter: Parameter,
  description: String,
) -> Parameter {
  Parameter(..parameter, description: Some(description))
}

fn parameter_required(parameter: Parameter, required: Bool) -> Parameter {
  Parameter(..parameter, required: required)
}

fn parameter_deprecated(parameter: Parameter, deprecated: Bool) -> Parameter {
  Parameter(..parameter, deprecated: deprecated)
}

fn parameter_allow_empty_value(
  parameter: Parameter,
  allow_empty_value: Bool,
) -> Parameter {
  Parameter(..parameter, allow_empty_value: allow_empty_value)
}

fn parameter_schema(
  parameter: Parameter,
  type_: String,
  builder: fn(Schema) -> Schema,
) -> Parameter {
  Parameter(..parameter, schema: Some(builder(schema_create(type_))))
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type ParameterNS {
  ParameterNS(
    to_spec: fn(Parameter) -> spec.Spec,
    description: fn(Parameter, String) -> Parameter,
    required: fn(Parameter, Bool) -> Parameter,
    deprecated: fn(Parameter, Bool) -> Parameter,
    allow_empty_value: fn(Parameter, Bool) -> Parameter,
    schema: fn(Parameter, String, fn(Schema) -> Schema) -> Parameter,
  )
}

pub const parameter: ParameterNS = ParameterNS(
  to_spec: parameter_to_spec,
  description: parameter_description,
  required: parameter_required,
  deprecated: parameter_deprecated,
  allow_empty_value: parameter_allow_empty_value,
  schema: parameter_schema,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Media Type Object                                       //
//                                      –––––––––––––––––––                                      //
//                   https://swagger.io/specification/v3.2/#media-type-object                    //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type MediaType {
  MediaType(schema: Option(Schema), example: Option(String))
}

fn media_type_to_spec(media_type: MediaType) -> spec.Spec {
  spec.object([
    #("schema", spec.nullable(media_type.schema, schema.to_spec)),
    #("example", spec.nullable(media_type.example, spec.string)),
  ])
}

fn media_type_schema(
  media_type: MediaType,
  type_: String,
  builder: fn(Schema) -> Schema,
) -> MediaType {
  MediaType(..media_type, schema: Some(builder(schema_create(type_))))
}

fn media_type_example(media_type: MediaType, example: String) -> MediaType {
  MediaType(..media_type, example: Some(example))
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type MediaTypeNS {
  MediaTypeNS(
    to_spec: fn(MediaType) -> spec.Spec,
    schema: fn(MediaType, String, fn(Schema) -> Schema) -> MediaType,
    example: fn(MediaType, String) -> MediaType,
  )
}

pub const media_type: MediaTypeNS = MediaTypeNS(
  to_spec: media_type_to_spec,
  schema: media_type_schema,
  example: media_type_example,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Response Object                                         //
//                                       –––––––––––––––––                                       //
//                    https://swagger.io/specification/v3.2/#response-object                     //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Response {
  Response(
    summary: Option(String),
    description: Option(String),
    content: List(#(String, OrRef(MediaType))),
  )
}

fn response_to_spec(response: Response) -> spec.Spec {
  spec.object([
    #("summary", spec.nullable(response.summary, spec.string)),
    #("description", spec.nullable(response.description, spec.string)),
    #(
      "content",
      spec.object_of(response.content, fn(entry) {
        #(entry.0, or_ref_to_spec(entry.1, media_type.to_spec))
      }),
    ),
  ])
}

fn response_summary(response: Response, summary: String) -> Response {
  Response(..response, summary: Some(summary))
}

fn response_description(response: Response, description: String) -> Response {
  Response(..response, description: Some(description))
}

fn response_content(
  response: Response,
  type_: String,
  builder: fn(MediaType) -> MediaType,
) -> Response {
  Response(
    ..response,
    content: list.append(response.content, [
      #(type_, Value(builder(MediaType(schema: None, example: None)))),
    ]),
  )
}

fn response_content_ref(
  response: Response,
  type_: String,
  ref: String,
) -> Response {
  Response(
    ..response,
    content: list.append(response.content, [
      #(type_, Ref(ref)),
    ]),
  )
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type ResponseNS {
  ResponseNS(
    to_spec: fn(Response) -> spec.Spec,
    summary: fn(Response, String) -> Response,
    description: fn(Response, String) -> Response,
    content: fn(Response, String, fn(MediaType) -> MediaType) -> Response,
    content_ref: fn(Response, String, String) -> Response,
  )
}

pub const response: ResponseNS = ResponseNS(
  to_spec: response_to_spec,
  summary: response_summary,
  description: response_description,
  content: response_content,
  content_ref: response_content_ref,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                      Request Body Object                                      //
//                                     –––––––––––––––––––––                                     //
//                  https://swagger.io/specification/v3.2/#request-body-object                   //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type RequestBody {
  RequestBody(
    description: Option(String),
    content: List(#(String, OrRef(MediaType))),
    required: Bool,
  )
}

fn request_body_to_spec(request_body: RequestBody) -> spec.Spec {
  spec.object([
    #("description", spec.nullable(request_body.description, spec.string)),
    #(
      "content",
      spec.object_of(request_body.content, fn(entry) {
        #(entry.0, or_ref_to_spec(entry.1, media_type.to_spec))
      }),
    ),
    #("required", spec.boolean(request_body.required)),
  ])
}

fn request_body_description(
  request_body: RequestBody,
  description: String,
) -> RequestBody {
  RequestBody(..request_body, description: Some(description))
}

fn request_body_content(
  request_body: RequestBody,
  content: String,
  builder: fn(MediaType) -> MediaType,
) -> RequestBody {
  RequestBody(
    ..request_body,
    content: list.append(request_body.content, [
      #(content, Value(builder(MediaType(schema: None, example: None)))),
    ]),
  )
}

fn request_body_content_ref(
  request_body: RequestBody,
  content: String,
  ref: String,
) -> RequestBody {
  RequestBody(
    ..request_body,
    content: list.append(request_body.content, [
      #(content, Ref(ref)),
    ]),
  )
}

fn request_body_required(
  request_body: RequestBody,
  required: Bool,
) -> RequestBody {
  RequestBody(..request_body, required: required)
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type RequestBodyNS {
  RequestBodyNS(
    to_spec: fn(RequestBody) -> spec.Spec,
    description: fn(RequestBody, String) -> RequestBody,
    content: fn(RequestBody, String, fn(MediaType) -> MediaType) -> RequestBody,
    content_ref: fn(RequestBody, String, String) -> RequestBody,
    required: fn(RequestBody, Bool) -> RequestBody,
  )
}

pub const request_body: RequestBodyNS = RequestBodyNS(
  to_spec: request_body_to_spec,
  description: request_body_description,
  content: request_body_content,
  content_ref: request_body_content_ref,
  required: request_body_required,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Operation Object                                        //
//                                      ––––––––––––––––––                                       //
//                    https://swagger.io/specification/v3.2/#operation-object                    //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Operation {
  Operation(
    tags: List(String),
    summary: Option(String),
    description: Option(String),
    external_docs: Option(ExternalDocs),
    operation_id: Option(String),
    parameters: List(OrRef(Parameter)),
    responses: List(#(Int, OrRef(Response))),
    security: List(String),
    request_body: Option(RequestBody),
  )
}

fn create_operation() -> Operation {
  Operation(
    tags: [],
    summary: None,
    description: None,
    external_docs: None,
    operation_id: None,
    parameters: [],
    responses: [],
    security: [],
    request_body: None,
  )
}

fn operation_to_spec(operation: Operation) -> spec.Spec {
  spec.object([
    #("tags", spec.array_of(operation.tags, spec.string)),
    #("summary", spec.nullable(operation.summary, spec.string)),
    #("description", spec.nullable(operation.description, spec.string)),
    #("operationId", spec.nullable(operation.operation_id, spec.string)),
    #(
      "parameters",
      spec.array_of(operation.parameters, or_ref_to_spec(_, parameter.to_spec)),
    ),
    #(
      "responses",
      spec.object_of(operation.responses, fn(entry) {
        #(int.to_string(entry.0), or_ref_to_spec(entry.1, response.to_spec))
      }),
    ),
    #(
      "security",
      spec.array_of(operation.security, fn(sec) {
        spec.object([#(sec, spec.array([]))])
      }),
    ),
    #(
      "requestBody",
      spec.nullable(operation.request_body, request_body_to_spec),
    ),
  ])
}

pub fn operation_tag(operation: Operation, tag: String) -> Operation {
  Operation(..operation, tags: list.append(operation.tags, [tag]))
}

pub fn operation_summary(operation: Operation, summary: String) -> Operation {
  Operation(..operation, summary: Some(summary))
}

pub fn operation_description(
  operation: Operation,
  description: String,
) -> Operation {
  Operation(..operation, description: Some(description))
}

pub fn operation_parameter(
  operation: Operation,
  name: String,
  in: ParameterIn,
  builder: fn(Parameter) -> Parameter,
) -> Operation {
  Operation(
    ..operation,
    parameters: list.append(operation.parameters, [
      Value(
        builder(Parameter(
          name,
          in,
          required: False,
          description: None,
          deprecated: False,
          allow_empty_value: False,
          schema: None,
        )),
      ),
    ]),
  )
}

pub fn operation_parameter_ref(operation: Operation, ref: String) -> Operation {
  Operation(
    ..operation,
    parameters: list.append(operation.parameters, [
      Ref(ref),
    ]),
  )
}

pub fn operation_response(
  operation: Operation,
  code: Int,
  builder: fn(Response) -> Response,
) -> Operation {
  Operation(
    ..operation,
    responses: list.append(operation.responses, [
      #(
        code,
        Value(builder(Response(summary: None, description: None, content: []))),
      ),
    ]),
  )
}

pub fn operation_response_ref(
  operation: Operation,
  code: Int,
  ref: String,
) -> Operation {
  Operation(
    ..operation,
    responses: list.append(operation.responses, [
      #(code, Ref(ref)),
    ]),
  )
}

pub fn operation_security(operation: Operation, security: String) -> Operation {
  Operation(..operation, security: list.append(operation.security, [security]))
}

pub fn opereation_request_body(
  operation: Operation,
  builder: fn(RequestBody) -> RequestBody,
) -> Operation {
  Operation(
    ..operation,
    request_body: Some(
      builder(RequestBody(description: None, content: [], required: False)),
    ),
  )
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type OperationNS {
  OperationNS(
    to_spec: fn(Operation) -> spec.Spec,
    tag: fn(Operation, String) -> Operation,
    summary: fn(Operation, String) -> Operation,
    description: fn(Operation, String) -> Operation,
    parameter: fn(Operation, String, ParameterIn, fn(Parameter) -> Parameter) ->
      Operation,
    parameter_ref: fn(Operation, String) -> Operation,
    response: fn(Operation, Int, fn(Response) -> Response) -> Operation,
    response_ref: fn(Operation, Int, String) -> Operation,
    security: fn(Operation, String) -> Operation,
    request_body: fn(Operation, fn(RequestBody) -> RequestBody) -> Operation,
  )
}

pub const operation = OperationNS(
  to_spec: operation_to_spec,
  tag: operation_tag,
  summary: operation_summary,
  description: operation_description,
  parameter: operation_parameter,
  parameter_ref: operation_parameter_ref,
  response: operation_response,
  response_ref: operation_response_ref,
  security: operation_security,
  request_body: opereation_request_body,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Path Item Object                                        //
//                                      ––––––––––––––––––                                       //
//                    https://swagger.io/specification/v3.2/#path-item-object                    //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type PathItem {
  PathItem(
    path: String,
    summary: Option(String),
    description: Option(String),
    get: Option(Operation),
    put: Option(Operation),
    post: Option(Operation),
    delete: Option(Operation),
  )
}

fn create_path_item(path: String) -> PathItem {
  PathItem(
    path: path,
    summary: None,
    description: None,
    get: None,
    put: None,
    post: None,
    delete: None,
  )
}

fn path_item_to_spec(path: PathItem) -> spec.Spec {
  spec.object([
    #("summary", spec.nullable(path.summary, spec.string)),
    #("description", spec.nullable(path.description, spec.string)),
    #("get", spec.nullable(path.get, operation.to_spec)),
    #("put", spec.nullable(path.put, operation.to_spec)),
    #("post", spec.nullable(path.post, operation.to_spec)),
    #("delete", spec.nullable(path.delete, operation.to_spec)),
  ])
}

fn path_item_get(
  path: PathItem,
  builder: fn(Operation) -> Operation,
) -> PathItem {
  PathItem(..path, get: case path.get {
    Some(get) -> Some(builder(get))
    None -> Some(builder(create_operation()))
  })
}

fn path_item_put(
  path: PathItem,
  builder: fn(Operation) -> Operation,
) -> PathItem {
  PathItem(..path, put: case path.put {
    Some(put) -> Some(builder(put))
    None -> Some(builder(create_operation()))
  })
}

fn path_item_post(
  path: PathItem,
  builder: fn(Operation) -> Operation,
) -> PathItem {
  PathItem(..path, post: case path.post {
    Some(post) -> Some(builder(post))
    None -> Some(builder(create_operation()))
  })
}

fn path_item_delete(
  path: PathItem,
  builder: fn(Operation) -> Operation,
) -> PathItem {
  PathItem(..path, delete: case path.delete {
    Some(delete) -> Some(builder(delete))
    None -> Some(builder(create_operation()))
  })
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type PathItemNS {
  PathItemNS(
    to_spec: fn(PathItem) -> spec.Spec,
    get: fn(PathItem, fn(Operation) -> Operation) -> PathItem,
    put: fn(PathItem, fn(Operation) -> Operation) -> PathItem,
    post: fn(PathItem, fn(Operation) -> Operation) -> PathItem,
    delete: fn(PathItem, fn(Operation) -> Operation) -> PathItem,
  )
}

pub const path: PathItemNS = PathItemNS(
  to_spec: path_item_to_spec,
  get: path_item_get,
  put: path_item_put,
  post: path_item_post,
  delete: path_item_delete,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                          Tag Object                                           //
//                                         ––––––––––––                                          //
//                       https://swagger.io/specification/v3.2/#tag-object                       //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Tag {
  Tag(
    name: String,
    summary: Option(String),
    description: Option(String),
    external_docs: Option(ExternalDocs),
    parent: Option(String),
    kind: Option(String),
  )
}

fn tag_to_spec(tag: Tag) -> spec.Spec {
  spec.object([
    #("name", spec.string(tag.name)),
    #("summary", spec.nullable(tag.summary, spec.string)),
    #("description", spec.nullable(tag.description, spec.string)),
    // #("externalDocs", spec.nullable(tag.external_docs, external_docs.to_spec)),
    #("parent", spec.nullable(tag.parent, spec.string)),
    #("kind", spec.nullable(tag.kind, spec.string)),
  ])
}

pub fn tag_summary(tag: Tag, summary: String) -> Tag {
  Tag(..tag, summary: Some(summary))
}

pub fn tag_description(tag: Tag, description: String) -> Tag {
  Tag(..tag, description: Some(description))
}

pub fn tag_kind(tag: Tag, kind: String) -> Tag {
  Tag(..tag, kind: Some(kind))
}

pub fn tag_parent(tag: Tag, parent: String) -> Tag {
  Tag(..tag, parent: Some(parent))
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type TagNS {
  TagNS(
    to_spec: fn(Tag) -> spec.Spec,
    summary: fn(Tag, String) -> Tag,
    description: fn(Tag, String) -> Tag,
    kind: fn(Tag, String) -> Tag,
    parent: fn(Tag, String) -> Tag,
  )
}

pub const tag: TagNS = TagNS(
  to_spec: tag_to_spec,
  summary: tag_summary,
  description: tag_description,
  kind: tag_kind,
  parent: tag_parent,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                    Security Scheme Object                                     //
//                                   ––––––––––––––––––––––––                                    //
//                 https://swagger.io/specification/v3.2/#security-scheme-object                 //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type SecuritySchemeIn {
  SecuritySchemeInQuery
  SecuritySchemeInHeader
  SecuritySchemeInCookie
}

pub type SecurityScheme {
  SecurityScheme(
    type_: String,
    description: Option(String),
    name: Option(String),
    in: Option(SecuritySchemeIn),
    scheme: Option(String),
    bearer_format: Option(String),
  )
}

fn security_scheme_to_spec(security_scheme: SecurityScheme) -> spec.Spec {
  spec.object([
    #("type", spec.string(security_scheme.type_)),
    #("description", spec.nullable(security_scheme.description, spec.string)),
    #("name", spec.nullable(security_scheme.name, spec.string)),
    #(
      "in",
      spec.nullable(security_scheme.in, fn(in) {
        spec.string(case in {
          SecuritySchemeInQuery -> "query"
          SecuritySchemeInHeader -> "header"
          SecuritySchemeInCookie -> "cookie"
        })
      }),
    ),
    #("scheme", spec.nullable(security_scheme.scheme, spec.string)),
    #("bearerFormat", spec.nullable(security_scheme.bearer_format, spec.string)),
  ])
}

fn security_scheme_description(
  security_scheme: SecurityScheme,
  description: String,
) -> SecurityScheme {
  SecurityScheme(..security_scheme, description: Some(description))
}

fn security_scheme_type(
  security_scheme: SecurityScheme,
  type_: String,
) -> SecurityScheme {
  SecurityScheme(..security_scheme, type_: type_)
}

fn security_scheme_name(
  security_scheme: SecurityScheme,
  name: String,
) -> SecurityScheme {
  SecurityScheme(..security_scheme, name: Some(name))
}

fn security_scheme_in(
  security_scheme: SecurityScheme,
  in: SecuritySchemeIn,
) -> SecurityScheme {
  SecurityScheme(..security_scheme, in: Some(in))
}

fn security_scheme_scheme(
  security_scheme: SecurityScheme,
  scheme: String,
) -> SecurityScheme {
  SecurityScheme(..security_scheme, scheme: Some(scheme))
}

fn security_scheme_bearer_format(
  security_scheme: SecurityScheme,
  bearer_format: String,
) -> SecurityScheme {
  SecurityScheme(..security_scheme, bearer_format: Some(bearer_format))
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type SecuritySchemeNS {
  SecuritySchemeNS(
    to_spec: fn(SecurityScheme) -> spec.Spec,
    description: fn(SecurityScheme, String) -> SecurityScheme,
    type_: fn(SecurityScheme, String) -> SecurityScheme,
    name: fn(SecurityScheme, String) -> SecurityScheme,
    in: fn(SecurityScheme, SecuritySchemeIn) -> SecurityScheme,
    scheme: fn(SecurityScheme, String) -> SecurityScheme,
    bearer_format: fn(SecurityScheme, String) -> SecurityScheme,
  )
}

pub const security_scheme: SecuritySchemeNS = SecuritySchemeNS(
  to_spec: security_scheme_to_spec,
  description: security_scheme_description,
  type_: security_scheme_type,
  name: security_scheme_name,
  in: security_scheme_in,
  scheme: security_scheme_scheme,
  bearer_format: security_scheme_bearer_format,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                       Components Object                                       //
//                                      –––––––––––––––––––                                      //
//                   https://swagger.io/specification/v3.2/#components-object                    //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type Components {
  Components(
    schemas: List(#(String, Schema)),
    responses: List(#(String, Response)),
    parameters: List(#(String, Parameter)),
    security_schemes: List(#(String, SecurityScheme)),
  )
}

fn components_to_spec(components: Components) -> spec.Spec {
  spec.object([
    #("schemas", spec.object_of_tuple(components.schemas, schema.to_spec)),
    #("responses", spec.object_of_tuple(components.responses, response.to_spec)),
    #(
      "parameters",
      spec.object_of_tuple(components.parameters, parameter.to_spec),
    ),
    #(
      "securitySchemes",
      spec.object_of_tuple(components.security_schemes, security_scheme_to_spec),
    ),
  ])
}

fn components_schema(
  openapi: OpenAPI,
  name: String,
  type_: String,
  builder: fn(Schema) -> Schema,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    components: Components(
      ..openapi.components,
      schemas: list.append(openapi.components.schemas, [
        #(name, builder(schema_create(type_))),
      ]),
    ),
  )
}

fn components_response(
  openapi: OpenAPI,
  name: String,
  builder: fn(Response) -> Response,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    components: Components(
      ..openapi.components,
      responses: list.append(openapi.components.responses, [
        #(
          name,
          builder(Response(summary: None, description: None, content: [])),
        ),
      ]),
    ),
  )
}

fn components_parameter(
  openapi: OpenAPI,
  ref: String,
  name: String,
  in: ParameterIn,
  builder: fn(Parameter) -> Parameter,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    components: Components(
      ..openapi.components,
      parameters: list.append(openapi.components.parameters, [
        #(
          ref,
          builder(Parameter(
            name: name,
            in: in,
            description: None,
            required: False,
            deprecated: False,
            allow_empty_value: False,
            schema: None,
          )),
        ),
      ]),
    ),
  )
}

fn components_security_scheme(
  openapi: OpenAPI,
  ref: String,
  type_: String,
  builder: fn(SecurityScheme) -> SecurityScheme,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    components: Components(
      ..openapi.components,
      security_schemes: list.append(openapi.components.security_schemes, [
        #(
          ref,
          builder(SecurityScheme(
            type_: type_,
            description: None,
            name: None,
            in: None,
            scheme: None,
            bearer_format: None,
          )),
        ),
      ]),
    ),
  )
}

// ––––––––––––––––––––––––––––––––––––––––– Namespace ––––––––––––––––––––––––––––––––––––––––– //

pub type ComponentsNS {
  ComponentsNS(
    to_spec: fn(Components) -> spec.Spec,
    schema: fn(OpenAPI, String, String, fn(Schema) -> Schema) -> OpenAPI,
    response: fn(OpenAPI, String, fn(Response) -> Response) -> OpenAPI,
    parameter: fn(
      OpenAPI,
      String,
      String,
      ParameterIn,
      fn(Parameter) -> Parameter,
    ) -> OpenAPI,
    security_scheme: fn(
      OpenAPI,
      String,
      String,
      fn(SecurityScheme) -> SecurityScheme,
    ) -> OpenAPI,
  )
}

pub const components: ComponentsNS = ComponentsNS(
  to_spec: components_to_spec,
  schema: components_schema,
  response: components_response,
  parameter: components_parameter,
  security_scheme: components_security_scheme,
)

// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //
//                                        OpenAPI Object                                         //
//                                       ––––––––––––––––                                        //
//                     https://swagger.io/specification/v3.2/#openapi-object                     //
// ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– //

pub type OpenAPI {
  OpenAPI(
    version: String,
    info: Info,
    servers: List(Server),
    paths: List(PathItem),
    tags: List(Tag),
    components: Components,
  )
}

pub fn openapi() -> OpenAPI {
  OpenAPI(
    version: "3.2.0",
    info: Info(
      title: "Generated API",
      summary: None,
      description: None,
      terms_of_service: None,
      contact: None,
      license: None,
      version: "1.0.0",
    ),
    servers: [],
    paths: [],
    tags: [],
    components: Components(
      schemas: [],
      responses: [],
      parameters: [],
      security_schemes: [],
    ),
  )
}

pub fn title(openapi: OpenAPI, title: String) -> OpenAPI {
  OpenAPI(..openapi, info: Info(..openapi.info, title: title))
}

pub fn version(openapi: OpenAPI, version: String) -> OpenAPI {
  OpenAPI(..openapi, info: Info(..openapi.info, version: version))
}

pub fn add_server(
  openapi: OpenAPI,
  uri: Uri,
  builder: fn(Server) -> Server,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    servers: list.append(openapi.servers, [
      builder(Server(url: uri, description: None, name: None, variables: [])),
    ]),
  )
}

pub fn add_tag(
  openapi: OpenAPI,
  name: String,
  builder: fn(Tag) -> Tag,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    tags: list.append(openapi.tags, [
      builder(Tag(
        name: name,
        summary: None,
        description: None,
        external_docs: None,
        kind: None,
        parent: None,
      )),
    ]),
  )
}

pub fn add_path(
  openapi: OpenAPI,
  path: String,
  builder: fn(PathItem) -> PathItem,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    paths: list.append(openapi.paths, [builder(create_path_item(path))]),
  )
}

pub fn on_path(
  openapi: OpenAPI,
  path: String,
  builder: fn(PathItem) -> PathItem,
) -> OpenAPI {
  OpenAPI(
    ..openapi,
    paths: modify_or_add(
      openapi.paths,
      fn(item) { item.path == path },
      builder,
      fn() { create_path_item(path) },
    ),
  )
}

fn separate(list: List(a), filter: fn(a) -> Bool) -> #(List(a), List(a)) {
  separate_loop(list, filter, [], [])
}

fn separate_loop(
  list: List(a),
  predicate: fn(a) -> Bool,
  matched: List(a),
  unmatched: List(a),
) -> #(List(a), List(a)) {
  case list {
    [] -> #(list.reverse(matched), list.reverse(unmatched))
    [first, ..rest] -> {
      let #(new_matched, new_unmatched) = case predicate(first) {
        True -> #([first, ..matched], unmatched)
        False -> #(matched, [first, ..unmatched])
      }
      separate_loop(rest, predicate, new_matched, new_unmatched)
    }
  }
}

fn modify_or_add(
  list: List(a),
  filter: fn(a) -> Bool,
  modify: fn(a) -> a,
  create: fn() -> a,
) -> List(a) {
  let #(matched, unmatched) = separate(list, filter)

  case matched {
    [] -> list.append(unmatched, [modify(create())])
    [first, ..rest] -> list.append(unmatched, [modify(first), ..rest])
  }
}

pub fn to_spec(openapi: OpenAPI) -> spec.Spec {
  spec.object([
    #("openapi", spec.string(openapi.version)),
    #("info", info.to_spec(openapi.info)),
    #("servers", spec.array_of(openapi.servers, server.to_spec)),
    #(
      "paths",
      spec.object_of(openapi.paths, fn(path) {
        #(
          case path.path {
            "/" <> rest -> "/" <> rest
            _ -> "/" <> path.path
          },
          path_item_to_spec(path),
        )
      }),
    ),
    #("tags", spec.array_of(openapi.tags, tag.to_spec)),
    #("components", components.to_spec(openapi.components)),
  ])
  |> spec.omit_null()
}
