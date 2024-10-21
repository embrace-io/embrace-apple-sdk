//
//  Copyright © 2023 Embrace Mobile, Inc. All rights reserved.
//

import SwiftUI
import Apollo

struct ApolloStressTest: View {
    let client = ApolloClient.example(
        queue: OperationQueue(),
        endpointURL: URL(string: "https://swapi-graphql.netlify.app/.netlify/functions/index")!
    )

    @State var result = ""

    var body: some View {
        Button(action: performRequest) {
            Text("Send Apollo Request")
        }
        .buttonStyle(.borderedProminent)

        if result.isEmpty {
            Spacer()
        } else {
            Text("Result")
            Text(result)
        }
    }

    func performRequest() {
        result = ""

        let query = StarWarsAPI.Query()
        client.fetch(query: query, cachePolicy: .fetchIgnoringCacheData) { result in
            switch result {
            case .success(let graphQLResult):
                self.result = String(describing: graphQLResult.data)
            case .failure(let error):
                self.result = error.localizedDescription
            }
        }

    }
}

#Preview {
    ApolloStressTest()
}
