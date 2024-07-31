//
//  Copyright © 2024 Embrace Mobile, Inc. All rights reserved.
//

import Foundation
import GRDB

extension EmbraceStorage {
    internal func dbFetchAsync<T: FetchableRecord & TableRecord>(
        block: @escaping (Database) throws -> [T],
        completion: @escaping (Result<[T], Error>) -> Void) {

        dbQueue.asyncRead { result in
            switch result {
            case .success(let db):
                do {
                    let fetch = try block(db)
                    completion(.success(fetch))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    internal func dbFetchOneAsync<T: FetchableRecord & TableRecord>(
        block: @escaping (Database) throws -> T?,
        completion: @escaping (Result<T?, Error>) -> Void) {

        dbQueue.asyncRead { result in
            switch result {
            case .success(let db):
                do {
                    let fetch = try block(db)
                    completion(.success(fetch))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    internal func dbFetchCountAsync(
        block: @escaping (Database) throws -> Int,
        completion: @escaping (Result<Int, Error>) -> Void) {

        dbQueue.asyncRead { result in
            switch result {
            case .success(let db):
                do {
                    let fetch = try block(db)
                    completion(.success(fetch))
                } catch {
                    completion(.failure(error))
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    internal func dbWriteAsync<T>(
        block: @escaping (Database) throws -> T,
        completion: ((Result<T, Error>) -> Void)?) {

        dbQueue.asyncWrite { db in
            try block(db)
        } completion: { _, result in
            completion?(result)
        }
    }
}
