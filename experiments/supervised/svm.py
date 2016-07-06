import datetime
import numpy as np
import pickle
import h5py
import scipy.stats
import sklearn.decomposition
import sklearn.ensemble
import sklearn.linear_model
import sklearn.metrics
import sklearn.preprocessing

np.set_printoptions(precision=2)

# Load
print(datetime.datetime.now().time().strftime('%H:%M:%S') + " Loading")
hdf5_time_file = h5py.File("dcase2013_timeQ8_test.mat")
X_time = hdf5_time_file["dcase2013_timeQ8_test"]["X_test"]
Y = np.ravel(hdf5_time_file["dcase2013_timeQ8_test"][u'Y_test'])
hdf5_timefrequency_file = h5py.File("dcase2013_timefrequencyQ8_test.mat")
X_timefrequency = hdf5_timefrequency_file[
    "dcase2013_timefrequencyQ8_test"]["X_test"]

folds = np.mod(np.arange(100), 5)

for augmentation in [True, False], method in ['time', 'timefrequency'],
    selection in [False, True], integration in ['early', 'true']:
        method_str = method
        if augmentation:
            method_str = method_str + "_augmentation"
        if selection:
            method_str = method_str + "_selection"
        method_str = method_str + "_" + integration
        print "Method: " + method_str

        if method == "time":
            X = X_time
        if method == "timefrequency":
            X = X_timefrequency

        # Rectify
        X = np.maximum(0.0, X)

        # Split folds
        X = np.reshape(X,
            (X.shape[0] / 5,   #  20 scenes per fold
             5,                #   5 folds
             X.shape[1],       #   5 azimuths
             X.shape[2],       # 128 time
             X.shape[3]))      # ~1k features

        # Early integration
        X_early = np.sum(X, 3)[:, :, :, np.newaxis, :]

        for fold_id in range(5):
            if integration == "early":
                X_int = X_early
            if integration == "late":
                X_int = X

            Y_training = Y[folds != fold_id]
            Y_test = Y[folds == fold_id]

            if integration == "late":
                Y_training = np.repeat(Y_training, 128)

            # Concatenate azimuths as different training examples
            if augmentation:
                X_training = X_int[:, np.arange(5)!=fold_id, :, :, :]
                Y_training = np.repeat(Y_training, 5)
            else:
                X_training = X_int[:, np.arange(5)!=fold_id, :, :, :]
            # Pick central azimuth at test time
            X_test = X_int[:, fold_id, 2, :, :]

            X_training = np.reshape(X_training,
                (np.prod(X_training.shape[0:-1]), X_training.shape[-1]))
            X_test = np.reshape(X_test,
                (np.prod(X_test.shape[0:-1]), X_test.shape[-1]))

            # Discard features with less than 1% of the energy
            if selection:
                energies = X_training * X_training
                feature_energies = np.mean(X_training, axis=0)
                feature_energies /= np.sum(feature_energies)
                sorting_indices = np.argsort(feature_energies)
                sorted_feature_energies = feature_energies[sorting_indices]
                cumulative = np.cumsum(sorted_feature_energies)
                start_feature = np.where(cumulative > 0.01)[0][0]
                dominant_indices = sorting_indices[start_feature:]
                X_training = X_training[:, dominant_indices]
                X_test = X_test[:, dominant_indices]

            # Log transformation (1e2 is what yields the lowest skewness)
            medians = np.median(X_training, axis=0)[np.newaxis, :]
            X_training = np.log1p(1e2 * X_training / medians)
            X_test = np.log1p(1e2 * X_test / medians)

            # Standardize features
            scaler = sklearn.preprocessing.StandardScaler().fit(X_training)
            X_training = scaler.transform(X_training)
            X_test = scaler.transform(X_test)
            report = []
            output_file = open(
                'mdb' + method_str + 'fold' + str(fold_id) + '.pkl', 'wb')
            pickle.dump(report, output_file)
            output_file.close()

            # Train linear SVM
            clf = sklearn.svm.LinearSVC(class_weight="balanced")
            clf.fit(X_training, Y_training)

            # Predict and evaluate average miss rate
            if integration == "early":
                Y_test_predicted = clf.predict(X_test)
            if integration == "late":
                logprobs_test = clf.predict_log_proba(X_test)
                logprobs_test = np.reshape(
                    logprobs_test.shape[0],
                    128,
                    logprobs_test.shape[1] / 128)
                sumlogprobs_test = np.sum(logprobs_test, axis=1)
                Y_test_predicted = np.argmax(sumlogprobs_test, axis=0)
            accuracy =\
                sklearn.metrics.accuracy_score(Y_test_predicted, Y_test)
            print "Accuracy = " + str(100 * accuracy)
            print ""
            dictionary = {
                'accuracy': accuracy,
                'augmentation': augmentation,
                'fold_id': fold_id,
                'integration': integration,
                'method': method,
                'method_str': method_str,
                'selection': selection,
                'Y_test': Y_test,
                'Y_test_predicted': Y_test_predicted}
            output_file = open(method_str + '.pkl', 'wb')
            pickle.dump(dictionary, output_file)
            output_file.close()
