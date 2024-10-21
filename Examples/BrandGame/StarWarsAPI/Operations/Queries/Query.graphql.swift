// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public extension StarWarsAPI {
  class Query: GraphQLQuery {
    public static let operationName: String = "Query"
    public static let document: ApolloAPI.DocumentType = .notPersisted(
      definition: .init(
        #"""
        query Query {
          allFilms {
            __typename
            films {
              __typename
              title
              director
              releaseDate
              speciesConnection {
                __typename
                species {
                  __typename
                  name
                  classification
                  homeworld {
                    __typename
                    name
                  }
                }
              }
            }
          }
        }
        """#
      ))

    public init() {}

    public struct Data: StarWarsAPI.SelectionSet {
      public let __data: DataDict
      public init(data: DataDict) { __data = data }

      public static var __parentType: ApolloAPI.ParentType { StarWarsAPI.Objects.Root }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("allFilms", AllFilms?.self)
      ] }

      public var allFilms: AllFilms? { __data["allFilms"] }

      /// AllFilms
      ///
      /// Parent Type: `FilmsConnection`
      public struct AllFilms: StarWarsAPI.SelectionSet {
        public let __data: DataDict
        public init(data: DataDict) { __data = data }

        public static var __parentType: ApolloAPI.ParentType { StarWarsAPI.Objects.FilmsConnection }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("films", [Film?]?.self)
        ] }

        /// A list of all of the objects returned in the connection. This is a convenience
        /// field provided for quickly exploring the API; rather than querying for
        /// "{ edges { node } }" when no edge data is needed, this field can be be used
        /// instead. Note that when clients like Relay need to fetch the "cursor" field on
        /// the edge to enable efficient pagination, this shortcut cannot be used, and the
        /// full "{ edges { node } }" version should be used instead.
        public var films: [Film?]? { __data["films"] }

        /// AllFilms.Film
        ///
        /// Parent Type: `Film`
        public struct Film: StarWarsAPI.SelectionSet {
          public let __data: DataDict
          public init(data: DataDict) { __data = data }

          public static var __parentType: ApolloAPI.ParentType { StarWarsAPI.Objects.Film }
          public static var __selections: [ApolloAPI.Selection] { [
            .field("title", String?.self),
            .field("director", String?.self),
            .field("releaseDate", String?.self),
            .field("speciesConnection", SpeciesConnection?.self)
          ] }

          /// The title of this film.
          public var title: String? { __data["title"] }
          /// The name of the director of this film.
          public var director: String? { __data["director"] }
          /// The ISO 8601 date format of film release at original creator country.
          public var releaseDate: String? { __data["releaseDate"] }
          public var speciesConnection: SpeciesConnection? { __data["speciesConnection"] }

          /// AllFilms.Film.SpeciesConnection
          ///
          /// Parent Type: `FilmSpeciesConnection`
          public struct SpeciesConnection: StarWarsAPI.SelectionSet {
            public let __data: DataDict
            public init(data: DataDict) { __data = data }

            public static var __parentType: ApolloAPI.ParentType { StarWarsAPI.Objects.FilmSpeciesConnection }
            public static var __selections: [ApolloAPI.Selection] { [
              .field("species", [Specy?]?.self)
            ] }

            /// A list of all of the objects returned in the connection. This is a convenience
            /// field provided for quickly exploring the API; rather than querying for
            /// "{ edges { node } }" when no edge data is needed, this field can be be used
            /// instead. Note that when clients like Relay need to fetch the "cursor" field on
            /// the edge to enable efficient pagination, this shortcut cannot be used, and the
            /// full "{ edges { node } }" version should be used instead.
            public var species: [Specy?]? { __data["species"] }

            /// AllFilms.Film.SpeciesConnection.Specy
            ///
            /// Parent Type: `Species`
            public struct Specy: StarWarsAPI.SelectionSet {
              public let __data: DataDict
              public init(data: DataDict) { __data = data }

              public static var __parentType: ApolloAPI.ParentType { StarWarsAPI.Objects.Species }
              public static var __selections: [ApolloAPI.Selection] { [
                .field("name", String?.self),
                .field("classification", String?.self),
                .field("homeworld", Homeworld?.self)
              ] }

              /// The name of this species.
              public var name: String? { __data["name"] }
              /// The classification of this species, such as "mammal" or "reptile".
              public var classification: String? { __data["classification"] }
              /// A planet that this species originates from.
              public var homeworld: Homeworld? { __data["homeworld"] }

              /// AllFilms.Film.SpeciesConnection.Specy.Homeworld
              ///
              /// Parent Type: `Planet`
              public struct Homeworld: StarWarsAPI.SelectionSet {
                public let __data: DataDict
                public init(data: DataDict) { __data = data }

                public static var __parentType: ApolloAPI.ParentType { StarWarsAPI.Objects.Planet }
                public static var __selections: [ApolloAPI.Selection] { [
                  .field("name", String?.self)
                ] }

                /// The name of this planet.
                public var name: String? { __data["name"] }
              }
            }
          }
        }
      }
    }
  }

}
